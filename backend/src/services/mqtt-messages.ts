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

export function decodeMqttJson(payload: Buffer): unknown {
  if (payload.length > 2048) throw new Error("Payload MQTT excede 2 KiB");
  return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(payload));
}
