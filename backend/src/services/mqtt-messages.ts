import { z } from "zod";

export const mqttPrefix = (terminalId: string) => `access/v1/terminals/${terminalId}`;

export const mqttEnvelope = z.object({
  schemaVersion: z.literal(1),
  terminalId: z.uuid(),
  eventId: z.uuid(),
});

export const mqttEvent = mqttEnvelope.extend({ occurredAt: z.iso.datetime() });
export const mqttRequest = mqttEvent.extend({ requestId: z.uuid() });
export const accessWindowMs = 5_000;
export const heartbeatWindowMs = 30_000;
export const unlockDurationMs = 3_000;
export const doorOpeningMs = 5_120;
export const doorAckWindowMs = 10_000;

export const doorAck = mqttRequest.extend({
  result: z.enum(["UNLOCKED", "EXPIRED", "ERROR"]),
  accessLogId: z.uuid(),
  acceptedAt: z.iso.datetime().optional(),
}).refine((ack) => (ack.result === "EXPIRED") === (ack.acceptedAt === undefined));

export type DoorAck = Pick<z.infer<typeof doorAck>,
  "terminalId" | "requestId" | "accessLogId" | "result" | "occurredAt" | "acceptedAt">;

export function doorAckTiming(ack: DoorAck) {
  const occurredAt = new Date(ack.occurredAt);
  if (ack.result === "EXPIRED") {
    if (ack.acceptedAt !== undefined) return null;
    return { occurredAt, expiration: { gte: new Date(occurredAt.getTime() - doorAckWindowMs), lte: occurredAt } };
  }
  if (ack.acceptedAt === undefined) return null;
  const acceptedAt = new Date(ack.acceptedAt);
  const elapsed = occurredAt.getTime() - acceptedAt.getTime();
  if (elapsed < 0 || elapsed > doorAckWindowMs) return null;
  return { occurredAt, acceptedAt, expiration: { gt: acceptedAt } };
}

export function decodeMqttJson(payload: Buffer): unknown {
  if (payload.length > 2048) throw new Error("Payload MQTT excede 2 KiB");
  return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(payload));
}
