import type { Prisma } from "../generated/prisma/client.js";
import { prisma } from "../config/prisma.js";
import { AppError } from "../middlewares/error.middleware.js";
import { configuredDoorTerminalId } from "./door-unlock.service.js";
import { accessWindowMs, doorAckWindowMs } from "./mqtt-messages.js";

type CheckoutType = "SIMPLE" | "POKEMON";

export const visitSelect = {
  id: true,
  user: { select: { id: true, name: true } },
  location: { select: { id: true, building: true, entrance: true, door: true, turnstile: true } },
  entryTerminal: { select: { id: true, name: true } },
  entryLog: { select: { id: true, method: true, commandAcked: true } },
  enteredAt: true,
  exitedAt: true,
  checkoutType: true,
  checkedOutBy: { select: { id: true, name: true } },
  pokemonDraw: { select: { collection: { select: { pokemonId: true, claimedAt: true } } } },
  checkoutDoorCommand: {
    select: { id: true, terminalId: true, issuedAt: true, expiresAt: true, ackAt: true, ackResult: true },
  },
} satisfies Prisma.visitSelect;

type VisitRecord = Prisma.visitGetPayload<{ select: typeof visitSelect }>;

function doorStatus(command: NonNullable<VisitRecord["checkoutDoorCommand"]>) {
  if (command.ackResult === "UNLOCKED") return "CONFIRMED";
  if (command.ackResult === "ERROR") return "FAILED";
  if (command.ackResult === "EXPIRED" || Date.now() >= command.expiresAt.getTime() + doorAckWindowMs) {
    return "EXPIRED";
  }
  return "PENDING";
}

export function toVisitResponse({ pokemonDraw, checkoutDoorCommand, ...visit }: VisitRecord) {
  return {
    ...visit,
    status: visit.exitedAt === null ? "INSIDE" : "EXITED",
    pokemon: pokemonDraw?.collection ?? null,
    doorCommand: checkoutDoorCommand
      ? { ...checkoutDoorCommand, status: doorStatus(checkoutDoorCommand) }
      : null,
  };
}

export async function lockVisit(tx: Prisma.TransactionClient, id: string) {
  const [visit] = await tx.$queryRaw<{
    id: string;
    userId: string | null;
    locationId: string;
    exitedAt: Date | null;
    checkoutType: CheckoutType | null;
  }[]>`
    SELECT "id", "userId", "locationId", "exitedAt", "checkoutType"
    FROM "visits" WHERE "id" = ${id}::uuid FOR UPDATE
  `;
  return visit;
}

export async function registerEntryVisit(
  db: Pick<Prisma.TransactionClient, "visit">,
  entry: { userId: string; locationId: string; terminalId: string; log: { id: string; createdAt: Date } },
): Promise<void> {
  await db.visit.createMany({
    data: {
      userId: entry.userId,
      locationId: entry.locationId,
      entryTerminalId: entry.terminalId,
      entryLogId: entry.log.id,
      enteredAt: entry.log.createdAt,
    },
    // O índice parcial impede duplicatas sem interromper a transação do acesso.
    skipDuplicates: true,
  });
}

export async function getVisit(id: string) {
  const visit = await prisma.visit.findUnique({ where: { id }, select: visitSelect });
  if (!visit) throw new AppError(404, "Visita não encontrada", "VISIT_NOT_FOUND");
  return toVisitResponse(visit);
}

export function checkoutVisit(id: string, actorId: string, type: CheckoutType) {
  return prisma.$transaction(async (tx) => {
    const visit = await lockVisit(tx, id);
    if (!visit) throw new AppError(404, "Visita não encontrada", "VISIT_NOT_FOUND");
    const where = { id: visit.id };
    if (visit.exitedAt) {
      if (visit.checkoutType !== type) {
        throw new AppError(409, "A visita já foi encerrada por outro tipo de checkout", "VISIT_ALREADY_CLOSED");
      }
      return toVisitResponse(await tx.visit.findUniqueOrThrow({ where, select: visitSelect }));
    }
    if (!visit.userId) throw new AppError(409, "A visita não tem usuário ativo no cadastro", "VISIT_NOT_OPEN");

    if (type === "POKEMON") {
      const draw = await tx.visitPokemonDraw.findUnique({ where: { visitId: visit.id } });
      if (!draw) throw new AppError(409, "Inicie o sorteio antes de confirmar", "POKEMON_DRAW_REQUIRED");

      const targetId = configuredDoorTerminalId();
      const target = targetId && await tx.terminal.findFirst({
        where: { id: targetId, locationId: visit.locationId },
        select: { id: true },
      });
      if (!target) {
        throw new AppError(409, "Nenhuma porta MQTT está configurada para o local da visita", "CHECKOUT_DOOR_UNAVAILABLE");
      }
      const issuedAt = new Date();
      await tx.userPokemon.create({
        data: { visitId: visit.id, userId: visit.userId, pokemonId: draw.pokemonId, claimedAt: issuedAt },
      });
      await tx.mqttDoorCommand.create({
        data: {
          checkoutVisitId: visit.id, terminalId: target.id, issuedAt,
          expiresAt: new Date(issuedAt.getTime() + accessWindowMs),
        },
      });
    }

    const updated = await tx.visit.update({
      where, data: { exitedAt: new Date(), checkoutType: type, checkedOutById: actorId },
      select: visitSelect,
    });
    return toVisitResponse(updated);
  });
}
