// backend/src/controllers/terminals.controller.ts
import { createHash, createHmac, randomBytes } from "node:crypto";
import type { Request, Response } from "express";
import type { Prisma } from "../generated/prisma/client.js";
import { prisma } from "../config/prisma.js";
import { AppError } from "../middlewares/error.middleware.js";
import {
  createTerminalSchema,
  idParamSchema,
  listTerminalsQuerySchema,
  updateTerminalSchema,
} from "../models/dtos/index.js";
import {
  paginate,
  toTerminalResponse,
  type TerminalCreatedResponse,
} from "../models/index.js";

const notFound = () =>
  new AppError(404, "Terminal não encontrado", "TERMINAL_NOT_FOUND");
const locationNotFound = () =>
  new AppError(404, "Local não encontrado", "LOCATION_NOT_FOUND");

/**
 * A apiKey é aleatória e longa (192 bits), então SHA-256 basta para guardá-la
 * (bcrypt seria lento demais a cada requisição do terminal).
 */
export const hashApiKey = (apiKey: string) =>
  createHash("sha256").update(apiKey).digest("hex");

// GET /terminals
export async function listTerminals(req: Request, res: Response) {
  const q = listTerminalsQuerySchema.parse(req.query);
  const where: Prisma.TerminalWhereInput = q.locationId
    ? { locationId: q.locationId }
    : {};

  const [rows, total] = await prisma.$transaction([
    prisma.terminal.findMany({
      where,
      include: { location: true },
      orderBy: { name: "asc" },
      skip: (q.page - 1) * q.pageSize,
      take: q.pageSize,
    }),
    prisma.terminal.count({ where }),
  ]);

  res.json(paginate(rows.map(toTerminalResponse), total, q.page, q.pageSize));
}

// GET /terminals/:id
export async function getTerminal(req: Request, res: Response) {
  const { id } = idParamSchema.parse(req.params);

  const terminal = await prisma.terminal.findUnique({
    where: { id },
    include: { location: true },
  });
  if (!terminal) throw notFound();

  res.json(toTerminalResponse(terminal));
}

// GET /terminals/:id/qr (US-11: token assinado do QR Code renovado a cada 10s)
export async function getTerminalQr(req: Request, res: Response) {
  const { id } = idParamSchema.parse(req.params);

  const terminal = await prisma.terminal.findUnique({ where: { id } });
  if (!terminal) throw notFound();

  const now = Date.now();
  const ttlSeconds = 10;
  // Expiração com 12s (tolerância de 2s para jitter de rede)
  const expiresAt = new Date(now + 12_000);
  const nonce = randomBytes(16).toString("hex");

  // Limpa nonces já vencidos deste terminal e grava novos (anti-replay)
  await prisma.$transaction([
    prisma.qrNonce.deleteMany({
      where: { terminalId: id, expiresAt: { lt: new Date(now) } },
    }),
    prisma.qrNonce.create({
      data: { nonce, terminalId: id, expiresAt },
    }),
  ]);

  // Assina o payload com o qrSecret do terminal
  const payloadObj = {
    terminalId: id,
    nonce,
    exp: expiresAt.getTime(),
  };
  const payloadB64 = Buffer.from(JSON.stringify(payloadObj)).toString(
    "base64url",
  );
  const signature = createHmac("sha256", terminal.qrSecret)
    .update(payloadB64)
    .digest("base64url");

  const token = `${payloadB64}.${signature}`;

  res.json({
    token,
    expiresAt: expiresAt.toISOString(),
    ttlSeconds,
  });
}

// GET /terminals/:id/status (US-16: fallback de presença quando MQTT cair)
export async function getTerminalStatus(req: Request, res: Response) {
  const { id } = idParamSchema.parse(req.params);

  const terminal = await prisma.terminal.findUnique({ where: { id } });
  if (!terminal) throw notFound();

  // Considera presença ativa se lastPresenceAt foi atualizado nos últimos 5 segundos
  const presenceActive =
    terminal.lastPresenceAt != null &&
    Date.now() - terminal.lastPresenceAt.getTime() <= 5_000;

  res.json({
    id: terminal.id,
    online: terminal.online,
    presence: presenceActive,
    presenceActive,
    lastPresenceAt: terminal.lastPresenceAt,
    lastSeenAt: terminal.lastSeenAt,
  });
}

// GET /terminals/:id/faces (US-14: entrega embeddings faciais dos usuários autorizados no local)
export async function getTerminalFaces(req: Request, res: Response) {
  const { id } = idParamSchema.parse(req.params);

  const terminal = await prisma.terminal.findUnique({
    where: { id },
    select: { id: true, locationId: true },
  });
  if (!terminal) throw notFound();

  const templates = await prisma.faceTemplate.findMany({
    where: {
      user: {
        active: true,
        authorizations: {
          some: {
            locationId: terminal.locationId,
            status: "ACTIVE",
          },
        },
      },
    },
    select: {
      userId: true,
      embedding: true,
      modelVersion: true,
    },
  });

  res.json({ data: templates });
}

// POST /terminals
export async function createTerminal(req: Request, res: Response) {
  const dto = createTerminalSchema.parse(req.body);

  const location = await prisma.location.findUnique({
    where: { id: dto.locationId },
    select: { id: true },
  });
  if (!location) throw locationNotFound();

  const apiKey = randomBytes(24).toString("hex");
  const terminal = await prisma.terminal.create({
    data: {
      ...dto,
      qrSecret: randomBytes(32).toString("hex"),
      apiKeyHash: hashApiKey(apiKey),
    },
    include: { location: true },
  });

  // A apiKey em texto puro só é devolvida agora; depois não há como recuperá-la.
  const body: TerminalCreatedResponse = {
    ...toTerminalResponse(terminal),
    apiKey,
  };
  res.status(201).json(body);
}

// PUT /terminals/:id
export async function updateTerminal(req: Request, res: Response) {
  const { id } = idParamSchema.parse(req.params);
  const dto = updateTerminalSchema.parse(req.body);

  if (dto.locationId) {
    const location = await prisma.location.findUnique({
      where: { id: dto.locationId },
      select: { id: true },
    });
    if (!location) throw locationNotFound();
  }

  const terminal = await prisma.terminal.update({
    where: { id },
    data: dto,
    include: { location: true },
  });

  res.json(toTerminalResponse(terminal));
}

// DELETE /terminals/:id
export async function deleteTerminal(req: Request, res: Response) {
  const { id } = idParamSchema.parse(req.params);

  const logs = await prisma.accessLog.count({ where: { terminalId: id } });
  if (logs > 0) {
    throw new AppError(
      409,
      "Terminal possui histórico de acessos e não pode ser removido",
      "TERMINAL_IN_USE",
    );
  }

  await prisma.terminal.delete({ where: { id } });

  res.status(204).send();
}
