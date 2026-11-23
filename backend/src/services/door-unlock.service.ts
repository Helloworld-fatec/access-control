import { env } from "../config/env.js";
import { prisma } from "../config/prisma.js";
import { ACCESS_RESULTS, type AccessMethod } from "../types/index.js";
import { accessWindowMs, doorAckTiming, type DoorAck } from "./mqtt-messages.js";

export interface DoorUnlockRequest {
  terminalId: string;
  userId: string;
  accessLogId: string;
  method: AccessMethod;
}

/** Agenda uma abertura somente para uma concessão persistida no mesmo local. */
export async function requestDoorUnlock(request: DoorUnlockRequest): Promise<void> {
  const targetId = env.ESP32_TERMINAL_ID ?? env.MQTT_SIMULATOR_TERMINAL_ID;
  if (!env.MQTT_URL || !targetId || (request.method !== "QR" && request.method !== "FACE")) return;
  try {
    const grant = await prisma.accesslog.findFirst({
      where: {
        id: request.accessLogId, terminalId: request.terminalId, userId: request.userId,
        method: request.method, result: ACCESS_RESULTS.GRANTED,
      },
      select: { createdAt: true, terminal: { select: { locationId: true } } },
    });
    if (!grant) return;
    const expiresAt = new Date(grant.createdAt.getTime() + accessWindowMs);
    if (expiresAt.getTime() <= Date.now()) return;
    const target = await prisma.terminal.findFirst({
      where: { id: targetId, locationId: grant.terminal.locationId },
      select: { id: true },
    });
    if (!target) return;

    // A chave única mantém um único comando mesmo se a solicitação for repetida.
    await prisma.mqttDoorCommand.createMany({
      data: { accessLogId: request.accessLogId, terminalId: target.id, issuedAt: grant.createdAt, expiresAt },
      skipDuplicates: true,
    });
  } catch {
    console.warn("Falha ao agendar comando MQTT de abertura", request.accessLogId);
  }
}

export async function recordDoorCommandAck(ack: DoorAck) {
  if (ack.requestId !== ack.accessLogId) return false;
  const timing = doorAckTiming(ack);
  if (!timing) return false;
  return prisma.$transaction(async (tx) => {
    const { count } = await tx.mqttDoorCommand.updateMany({
      where: {
        accessLogId: ack.accessLogId, terminalId: ack.terminalId, ackResult: null,
        issuedAt: { lte: timing.acceptedAt ?? timing.occurredAt },
        expiresAt: timing.expiration,
      },
      data: { ackResult: ack.result, ackAt: timing.occurredAt },
    });
    if (count === 0) return false;
    await tx.accesslog.update({
      where: { id: ack.accessLogId },
      data: { commandAcked: ack.result === "UNLOCKED" },
    });
    return true;
  });
}
