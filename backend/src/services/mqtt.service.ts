import { readFileSync } from "node:fs";
import { connect, type MqttClient } from "mqtt";
import { z } from "zod";
import { env } from "../config/env.js";
import { prisma } from "../config/prisma.js";
import { recordEsp32NfcAccess, recordEsp32NfcUnlockAck } from "../controllers/access.controller.js";
import { recordEnrollmentAck } from "./nfc-enrollment.service.js";
import { recordDoorCommandAck } from "./door-unlock.service.js";
import { issueOledQr } from "./oled-qr.service.js";
import {
  accessWindowMs, checkoutPokemonMethod, decodeMqttJson, doorAck, doorAckTiming, heartbeatWindowMs, mqttEvent, mqttPrefix, mqttRequest, unlockDurationMs,
} from "./mqtt-messages.js";

let client: MqttClient | undefined;
let subscribed = false;
let enrollmentTimer: NodeJS.Timeout | undefined;
let sendingEnrollment = false;
let doorCommandTimer: NodeJS.Timeout | undefined;
let sendingDoorCommands = false;
let oledQrRequest: { id: string; receivedAt: number; response: ReturnType<typeof issueOledQr> } | undefined;
const presenceEvent = mqttEvent.extend({ detected: z.boolean(), distanceCm: z.number().nonnegative().optional() });
const doorEvent = mqttEvent.extend({ state: z.enum(["OPEN", "CLOSED"]) });

export function mqttStatus() {
  if (!env.MQTT_URL) return "disabled";
  return client?.connected && subscribed ? "connected" : "disconnected";
}

export function startMqtt() {
  const { MQTT_URL: url, MQTT_CA_FILE: caFile, MQTT_BACKEND_PASSWORD: password } = env;
  if (client || !url || !caFile || !password) return;
  const terminalIds = [env.ESP32_TERMINAL_ID, env.MQTT_SIMULATOR_TERMINAL_ID].filter((id) => id !== undefined);
  const suffixes = ["status", "presence", "door/state", "access/request", "door/ack"];
  const topics = new Set(terminalIds.flatMap((id) => suffixes.map((suffix) => `${mqttPrefix(id)}/${suffix}`)));
  const simulatorId = env.MQTT_SIMULATOR_TERMINAL_ID;
  if (simulatorId) topics.add(`${mqttPrefix(simulatorId)}/nfc/enroll/ack`);
  if (env.ESP32_TERMINAL_ID) topics.add(`${mqttPrefix(env.ESP32_TERMINAL_ID)}/qr/request`);
  const connection = connect(url, {
    username: "backend",
    password,
    clientId: "access-control-backend",
    ca: readFileSync(caFile),
    rejectUnauthorized: true,
    protocolVersion: 5,
    clean: true,
    reconnectPeriod: 2_000,
    reconnectOnConnackError: true,
    resubscribe: false,
  });
  client = connection;
  connection.on("error", (error) => console.warn("Conexão MQTT:", error.message));
  connection.on("close", () => { subscribed = false; });
  connection.on("connect", () => {
    if (topics.size === 0) {
      subscribed = true;
      return;
    }
    connection.subscribe([...topics], { qos: 1 }, (error, grants) => {
      subscribed = !error && grants?.length === topics.size && grants.every(({ qos }) => qos === 1);
      if (!subscribed) {
        console.warn("MQTT: broker não confirmou todas as assinaturas.");
        connection.stream.destroy();
      }
    });
  });
  connection.on("message", (topic, payload, packet) => {
    if (packet.retain || !topics.has(topic)) return;
    void handleEsp32Message(connection, topic, decodeMqttJsonSafely(payload))
      .catch(() => console.warn("MQTT: evento inválido ou falha de processamento em", topic));
  });
  enrollmentTimer = setInterval(() => {
    if (!simulatorId || sendingEnrollment || mqttStatus() !== "connected") return;
    sendingEnrollment = true;
    void sendPendingEnrollments(connection, simulatorId)
      .catch(() => console.warn("MQTT: falha ao enviar gravação NFC."))
      .finally(() => { sendingEnrollment = false; });
  }, 1_000);
  enrollmentTimer.unref();
  doorCommandTimer = setInterval(() => {
    if (sendingDoorCommands || mqttStatus() !== "connected") return;
    sendingDoorCommands = true;
    void sendPendingDoorCommands(connection, terminalIds)
      .catch(() => console.warn("MQTT: falha ao enviar comando de abertura."))
      .finally(() => { sendingDoorCommands = false; });
  }, 500);
  doorCommandTimer.unref();
}

function decodeMqttJsonSafely(payload: Buffer): unknown {
  try {
    return decodeMqttJson(payload);
  } catch {
    return null;
  }
}

export async function stopMqtt() {
  const connection = client;
  client = undefined;
  subscribed = false;
  oledQrRequest = undefined;
  clearInterval(enrollmentTimer);
  clearInterval(doorCommandTimer);
  await connection?.endAsync(true);
}

async function sendPendingDoorCommands(connection: MqttClient, terminalIds: string[]) {
  const pending = await prisma.mqttDoorCommand.findMany({
    where: { terminalId: { in: terminalIds }, ackResult: null, expiresAt: { gt: new Date() } },
    include: { accessLog: { select: { method: true } } },
    orderBy: { issuedAt: "asc" },
  });
  for (const command of pending) {
    const remainingMs = command.expiresAt.getTime() - Date.now();
    if (remainingMs <= 0 || !connection.connected) continue;
    // Para checkout, os campos de correlação do protocolo transportam o UUID da visita.
    const requestId = command.checkoutVisitId ?? command.accessLogId;
    const method = command.checkoutVisitId ? checkoutPokemonMethod : command.accessLog?.method;
    if (!requestId || !method) continue;
    await connection.publishAsync(`${mqttPrefix(command.terminalId)}/door/command`, JSON.stringify({
      schemaVersion: 1,
      terminalId: command.terminalId,
      eventId: command.id,
      requestId,
      accessLogId: requestId,
      method,
      unlockDurationMs,
      occurredAt: command.issuedAt.toISOString(),
      expiresAt: command.expiresAt.toISOString(),
    }), { qos: 1, retain: false, properties: { messageExpiryInterval: Math.ceil(remainingMs / 1000) } });
  }
}

async function sendPendingEnrollments(connection: MqttClient, terminalId: string) {
  const pending = await prisma.nfcEnrollment.findMany({
    where: { terminalId, status: "PENDING", expiresAt: { gt: new Date() } },
    include: { user: { select: { nfcCredential: { select: { status: true, codeHex: true } } } } },
  });
  for (const enrollment of pending) {
    const credential = enrollment.user.nfcCredential;
    const remainingMs = enrollment.expiresAt.getTime() - Date.now();
    if (credential?.status !== "PENDING" || remainingMs <= 0 || !connection.connected) continue;
    await connection.publishAsync(`${mqttPrefix(enrollment.terminalId)}/nfc/enroll`, JSON.stringify({
      schemaVersion: 1,
      terminalId: enrollment.terminalId,
      eventId: enrollment.id,
      requestId: enrollment.id,
      credentialHex: credential.codeHex,
      ...(enrollment.expectedUid ? { expectedUid: enrollment.expectedUid } : {}),
      occurredAt: enrollment.createdAt.toISOString(),
      expiresAt: enrollment.expiresAt.toISOString(),
    }), { qos: 1, properties: { messageExpiryInterval: Math.ceil(remainingMs / 1000) } });
  }
}

async function handleEsp32Message(connection: MqttClient, topic: string, input: unknown) {
  const event = mqttEvent.parse(input);
  const prefix = mqttPrefix(event.terminalId);
  if (!topic.startsWith(`${prefix}/`)) return;
  const receivedAt = Date.now();
  const occurredAt = new Date(event.occurredAt);
  const age = receivedAt - occurredAt.getTime();
  if (age < -2_000 || age >= heartbeatWindowMs) return;
  const suffix = topic.slice(prefix.length + 1);
  const id = event.terminalId;

  switch (suffix) {
    case "nfc/enroll/ack":
      await recordEnrollmentAck(input);
      break;
    case "status":
      await prisma.terminal.updateMany({
        where: { id, OR: [{ lastSeenAt: null }, { lastSeenAt: { lt: occurredAt } }] },
        data: { lastSeenAt: occurredAt },
      });
      break;
    case "presence": {
      const { detected } = presenceEvent.parse(input);
      if (age >= accessWindowMs) return;
      await prisma.terminal.updateMany({
        where: { id, OR: [{ mqttPresenceAt: null }, { mqttPresenceAt: { lt: occurredAt } }] },
        data: { mqttPresenceAt: occurredAt, lastPresenceAt: detected ? occurredAt : null },
      });
      break;
    }
    case "door/state": {
      const { state } = doorEvent.parse(input);
      await prisma.terminal.updateMany({
        where: { id, OR: [{ mqttDoorStateAt: null }, { mqttDoorStateAt: { lt: occurredAt } }] },
        data: { mqttDoorStateAt: occurredAt, mqttDoorState: state },
      });
      break;
    }
    case "qr/request": {
      if (id !== env.ESP32_TERMINAL_ID || age >= accessWindowMs || !connection.connected) return;
      const { requestId } = mqttRequest.parse(input);
      if (oledQrRequest?.id !== requestId) {
        if (oledQrRequest && receivedAt - oledQrRequest.receivedAt < 2_000) return;
        const response = issueOledQr(id, requestId).catch((error: unknown) => {
          if (oledQrRequest?.response === response) oledQrRequest = undefined;
          throw error;
        });
        oledQrRequest = { id: requestId, receivedAt, response };
      }
      const display = await oledQrRequest.response;
      const remainingMs = Date.parse(display.expiresAt) - Date.now();
      if (!connection.connected || remainingMs <= 0 || Date.now() - occurredAt.getTime() >= accessWindowMs) return;
      await connection.publishAsync(`${prefix}/qr/display`, JSON.stringify(display), {
        qos: 1, retain: false, properties: { messageExpiryInterval: Math.ceil(remainingMs / 1000) },
      });
      break;
    }
    case "access/request": {
      if (age >= accessWindowMs || !connection.connected) return;
      const { requestId } = mqttRequest.parse(input);
      const expiresAt = new Date(occurredAt.getTime() + accessWindowMs);
      const outcome = await recordEsp32NfcAccess(topic, input, { requestId, occurredAt: event.occurredAt, expiresAt });
      const remainingMs = expiresAt.getTime() - Date.now();
      if (!outcome || !("decidedAt" in outcome) || !connection.connected || remainingMs <= 0) return;
      await connection.publishAsync(`${prefix}/access/decision`, JSON.stringify({
        schemaVersion: 1,
        terminalId: id,
        eventId: outcome.accessLogId,
        requestId,
        accessLogId: outcome.accessLogId,
        authorized: outcome.granted,
        reason: outcome.granted ? null : outcome.reason,
        unlockDurationMs: outcome.granted ? unlockDurationMs : 0,
        decidedAt: outcome.decidedAt,
        expiresAt: expiresAt.toISOString(),
      }), { qos: 1, properties: { messageExpiryInterval: Math.ceil(remainingMs / 1000) } });
      break;
    }
    case "door/ack": {
      const ack = doorAck.parse(input);
      if (ack.requestId === ack.accessLogId) {
        await recordDoorCommandAck(ack);
        return;
      }
      const timing = doorAckTiming(ack);
      if (!timing) return;
      const saved = await prisma.mqttNfcRequest.findUnique({
        where: { terminalId_requestId: { terminalId: id, requestId: ack.requestId } },
        select: { decision: true, expiresAt: true },
      });
      const decision = z.object({
        accessLogId: z.uuid(), granted: z.literal(true), decidedAt: z.iso.datetime(),
      }).safeParse(saved?.decision);
      if (!saved || !decision.success || decision.data.accessLogId !== ack.accessLogId) return;
      const { expiration, acceptedAt } = timing;
      if (acceptedAt && acceptedAt.getTime() < Date.parse(decision.data.decidedAt)) return;
      if (expiration.gt && saved.expiresAt <= expiration.gt) return;
      if (expiration.gte && saved.expiresAt < expiration.gte) return;
      if (expiration.lte && saved.expiresAt > expiration.lte) return;
      await recordEsp32NfcUnlockAck(topic, ack);
      break;
    }
  }
}
