import { createHash, randomBytes } from "node:crypto";
import { z } from "zod";
import { env } from "../config/env.js";
import { prisma } from "../config/prisma.js";
import { Prisma, type nfcEnrollment } from "../generated/prisma/client.js";
import { AppError } from "../middlewares/error.middleware.js";
import { nfcUidSchema } from "../models/dtos/nfc-tag.dto.js";
import { heartbeatWindowMs, mqttRequest } from "./mqtt-messages.js";

const enrollmentWindowMs = 30_000;
const writtenAck = mqttRequest.extend({
  result: z.literal("WRITTEN"), uid: nfcUidSchema, readbackSha256: z.string().regex(/^[a-f0-9]{64}$/),
});
const failedAck = mqttRequest.extend({
  result: z.enum(["FAILED", "TIMEOUT"]),
  reason: z.enum(["WRITE_FAILED", "READBACK_MISMATCH", "UID_MISMATCH", "TAG_NOT_PRESENT"]),
});
const enrollmentAck = z.discriminatedUnion("result", [writtenAck, failedAck]);

export const enrollmentResponseFields = {
  id: true, status: true, reason: true, expiresAt: true,
} as const;

export function toEnrollmentResponse(enrollment: Pick<nfcEnrollment, keyof typeof enrollmentResponseFields>) {
  if (enrollment.status === "PENDING" && enrollment.expiresAt.getTime() <= Date.now()) {
    return { ...enrollment, status: "EXPIRED", reason: "TAG_NOT_PRESENT" };
  }
  return enrollment;
}

export function enrollmentTerminalId() {
  return env.MQTT_SIMULATOR_TERMINAL_ID;
}

export async function lockEnrollmentUser(tx: Prisma.TransactionClient, userId: string) {
  const users = await tx.$queryRaw<{ id: string }[]>`SELECT id FROM users WHERE id = ${userId} FOR UPDATE`;
  return users.length > 0;
}

export async function beginEnrollment(userId: string, terminalId: string, expectedUid?: string) {
  for (let attempt = 0; attempt < 5; attempt += 1) {
    try {
      return await prisma.$transaction(async (tx) => {
        // Serializa a reserva do leitor, inclusive a troca de um pedido expirado.
        const [terminal] = await tx.$queryRaw<{ lastSeenAt: Date | null }[]>`
          SELECT "lastSeenAt" FROM terminals WHERE id = ${terminalId} FOR UPDATE
        `;
        if (!terminal?.lastSeenAt || Date.now() - terminal.lastSeenAt.getTime() >= heartbeatWindowMs) {
          throw new AppError(503, "O gravador NFC está indisponível", "NFC_READER_OFFLINE");
        }
        if (!await lockEnrollmentUser(tx, userId)) {
          throw new AppError(404, "Usuário não encontrado", "USER_NOT_FOUND");
        }
        const now = new Date();

        await tx.nfcEnrollment.updateMany({
          where: { OR: [{ terminalId }, { userId }], status: "PENDING", expiresAt: { lte: now } },
          data: { status: "EXPIRED", reason: "TAG_NOT_PRESENT" },
        });
        const pending = await tx.nfcEnrollment.findFirst({
          where: { OR: [{ terminalId }, { userId }], status: "PENDING" },
        });
        if (pending) {
          if (pending.terminalId === terminalId && pending.userId === userId &&
              pending.expectedUid === (expectedUid ?? null)) {
            return { id: pending.id, status: pending.status, reason: pending.reason, expiresAt: pending.expiresAt };
          }
          throw new AppError(409, "O gravador está ocupado com outro pedido", "NFC_READER_BUSY");
        }

        const credential = await tx.nfccredential.findUnique({ where: { userId } });
        if (credential?.status === "ACTIVE") {
          throw new AppError(409, "Remova a tag ativa antes de gravar outra", "NFC_CREDENTIAL_ACTIVE");
        }
        if (expectedUid) {
          const owner = await tx.nfctag.findUnique({ where: { uid: expectedUid }, select: { userId: true } });
          if (owner && owner.userId !== userId) {
            throw new AppError(409, "Esta tag já está cadastrada", "TAG_CONFLICT");
          }
        }

        const previous = credential && await tx.nfcEnrollment.findFirst({
          where: { userId }, select: { id: true },
        });
        if (!credential || previous || credential.status !== "PENDING") {
          let codeHex = randomBytes(3).toString("hex").toUpperCase();
          // Uma escrita anterior pode ter ocorrido sem confirmação. Invalida aquele código.
          while (codeHex === credential?.codeHex) codeHex = randomBytes(3).toString("hex").toUpperCase();
          await tx.nfccredential.upsert({
            where: { userId },
            create: { userId, codeHex },
            update: { codeHex, status: "PENDING", tagId: null },
          });
        }
        return tx.nfcEnrollment.create({
          data: { userId, terminalId, expectedUid, createdAt: now, expiresAt: new Date(now.getTime() + enrollmentWindowMs) },
          select: enrollmentResponseFields,
        });
      });
    } catch (error) {
      if (error instanceof AppError) throw error;
      if (!(error instanceof Prisma.PrismaClientKnownRequestError) || error.code !== "P2002") break;
    }
  }
  throw new AppError(503, "Não foi possível reservar a gravação NFC. Tente novamente", "NFC_ENROLLMENT_UNAVAILABLE");
}

export async function recordEnrollmentAck(input: unknown) {
  const ack = enrollmentAck.parse(input);
  await prisma.$transaction(async (tx) => {
    const pending = await tx.nfcEnrollment.findUnique({ where: { id: ack.requestId } });
    if (!pending || pending.terminalId !== ack.terminalId || pending.status !== "PENDING") return;
    if (!await lockEnrollmentUser(tx, pending.userId)) return;
    const now = new Date();
    if (new Date(ack.occurredAt) < pending.createdAt || new Date(ack.occurredAt) >= pending.expiresAt) return;
    // A atualização condicional serializa confirmações e expiração concorrentes.
    const claimed = await tx.nfcEnrollment.updateMany({
      where: { id: pending.id, status: "PENDING", expiresAt: { gt: now } },
      data: {
        status: ack.result === "TIMEOUT" ? "EXPIRED" : "FAILED",
        reason: ack.result === "WRITTEN" ? "READBACK_MISMATCH" : ack.reason,
      },
    });
    if (!claimed.count || ack.result !== "WRITTEN") return;

    const credential = await tx.nfccredential.findUnique({ where: { userId: pending.userId } });
    if (credential?.status !== "PENDING" ||
        createHash("sha256").update(Buffer.from(credential.codeHex, "hex")).digest("hex") !== ack.readbackSha256) return;
    if (pending.expectedUid && pending.expectedUid !== ack.uid) {
      await tx.nfcEnrollment.update({ where: { id: pending.id }, data: { reason: "UID_MISMATCH" } });
      return;
    }

    await tx.nfctag.createMany({
      data: { uid: ack.uid, userId: pending.userId },
      skipDuplicates: true,
    });
    const tag = await tx.nfctag.findUnique({ where: { uid: ack.uid } });
    if (!tag || tag.userId !== pending.userId) {
      await tx.nfcEnrollment.update({ where: { id: pending.id }, data: { reason: "TAG_CONFLICT" } });
      return;
    }
    if (!tag.active) await tx.nfctag.update({ where: { id: tag.id }, data: { active: true } });
    await tx.nfccredential.update({
      where: { userId: pending.userId },
      data: { status: "ACTIVE", tagId: tag.id },
    });
    await tx.nfcEnrollment.update({ where: { id: pending.id }, data: { status: "WRITTEN", reason: null } });
  });
}
