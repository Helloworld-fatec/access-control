import { createHash, randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";
import { createServer } from "node:http";
import { connect } from "mqtt";
import { z } from "zod";
import {
  accessWindowMs, decodeMqttJson, doorAckWindowMs, doorOpeningMs, mqttEnvelope, mqttPrefix, mqttRequest, unlockDurationMs,
} from "../services/mqtt-messages.js";

const terminalId = z.uuid().parse(process.env.MQTT_SIMULATOR_TERMINAL_ID || undefined);
const url = z.url({ protocol: /^mqtts$/ }).parse(process.env.MQTT_URL);
const caFile = z.string().min(1).parse(process.env.MQTT_CA_FILE);
const password = z.string().min(16).parse(process.env.MQTT_SIMULATOR_PASSWORD);
const prefix = mqttPrefix(terminalId);
const client = connect(url, {
  ca: readFileSync(caFile),
  rejectUnauthorized: true,
  username: "simulator",
  password,
  clientId: `simulator-${terminalId}`,
  protocolVersion: 5,
  reconnectPeriod: 2_000,
  reconnectOnConnackError: true,
  resubscribe: false,
  clean: true,
});

let ready = false;
let detected = false;
let doorState = "CLOSED";
let writeFault: "FAILED" | "TIMEOUT" | undefined;
let activeDoorRequest: string | undefined;
let uid = "04A32F1B";
const pendingReads = new Map<string, number>();
const completed = new Map<string, { expiresAt: number; topic: string; message: object; readyAt?: number }>();
const code = z.string().regex(/^[0-9A-F]{6}$/);
const uidSchema = z.string().regex(/^(?:[0-9A-F]{8}|[0-9A-F]{14}|[0-9A-F]{20})$/);
const expiry = z.iso.datetime();
const decision = mqttEnvelope.extend({
  requestId: z.uuid(), accessLogId: z.uuid(), authorized: z.boolean(), expiresAt: expiry,
  unlockDurationMs: z.number().int().min(0).max(unlockDurationMs),
});
const command = mqttRequest.extend({
  accessLogId: z.uuid(), method: z.enum(["QR", "FACE", "CHECKOUT_POKEMON"]), expiresAt: expiry,
  unlockDurationMs: z.number().int().positive().max(unlockDurationMs),
});
const enrollment = mqttRequest.extend({ credentialHex: code, expectedUid: z.string().optional(), expiresAt: expiry });

function event(data: object = {}) {
  return { schemaVersion: 1, terminalId, eventId: randomUUID(), occurredAt: new Date().toISOString(), ...data };
}

function publish(suffix: string, message: object) {
  if (ready && client.connected) client.publish(`${prefix}/${suffix}`, JSON.stringify(message), { qos: 1 });
}

function finish(requestId: string, expiresAt: number, topic: string, fields: object) {
  const message = event({ requestId, ...fields });
  completed.set(requestId, { expiresAt, topic, message });
  publish(topic, message);
}

client.on("error", (error) => console.warn("Simulador MQTT:", error.message));
client.on("close", () => { ready = false; });
client.on("connect", () => {
  client.subscribe(["access/decision", "door/command", "nfc/enroll"].map((topic) => `${prefix}/${topic}`),
    { qos: 1 }, (err, grants) => {
      ready = !err && grants?.length === 3 && grants.every(({ qos }) => qos === 1);
      if (!ready) {
        client.stream.destroy();
        return;
      }
      publish("status", event());
      publish("presence", event({ detected }));
      publish("door/state", event({ state: doorState }));
      for (const outcome of completed.values()) {
        if (outcome.topic === "door/ack" && outcome.expiresAt > Date.now()) publish(outcome.topic, outcome.message);
      }
      console.log("Simulador MQTT conectado.");
    });
});

client.on("message", (topic, payload, packet) => {
  if (packet.retain) return;
  try {
    const input = decodeMqttJson(payload);
    const enroll = topic === `${prefix}/nfc/enroll`;
    const nfcDecision = topic === `${prefix}/access/decision`;
    const order = enroll ? enrollment.parse(input) : nfcDecision ? decision.parse(input) : command.parse(input);
    const expiresAt = Date.parse(order.expiresAt);
    if (order.terminalId !== terminalId || order.requestId === activeDoorRequest) return;
    const previous = completed.get(order.requestId);
    if (previous) {
      if (Date.now() < previous.expiresAt && (!previous.readyAt || Date.now() >= previous.readyAt)) {
        publish(previous.topic, previous.message);
      }
      return;
    }
    if (expiresAt <= Date.now()) return;

    if ("credentialHex" in order) {
      if (writeFault === "TIMEOUT") {
        const readyAt = Math.max(Date.now(), expiresAt - 500);
        const result = event({
          requestId: order.requestId, result: "TIMEOUT", reason: "TAG_NOT_PRESENT",
          occurredAt: new Date(readyAt).toISOString(),
        });
        const timer = setTimeout(() => publish("nfc/enroll/ack", result), readyAt - Date.now());
        timer.unref();
        completed.set(order.requestId, { expiresAt, topic: "nfc/enroll/ack", message: result, readyAt });
      } else if (writeFault || (order.expectedUid && order.expectedUid !== uid)) {
        finish(order.requestId, expiresAt, "nfc/enroll/ack", {
          result: "FAILED", reason: writeFault ? "WRITE_FAILED" : "UID_MISMATCH",
        });
      } else {
        const tagBytes = Buffer.from(order.credentialHex, "hex");
        finish(order.requestId, expiresAt, "nfc/enroll/ack", {
          result: "WRITTEN", uid, readbackSha256: createHash("sha256").update(tagBytes).digest("hex"),
        });
      }
      return;
    }

    if ("authorized" in order) {
      const timeout = pendingReads.get(order.requestId);
      if (timeout === undefined || timeout <= Date.now()) return;
      pendingReads.delete(order.requestId);
      if (!order.authorized || order.unlockDurationMs === 0) return;
    }

    const accepted = Date.now();
    if (accepted >= expiresAt) return;
    const acceptedAt = new Date(accepted).toISOString();
    const ackDeadline = accepted + doorAckWindowMs;
    const ack = { accessLogId: order.accessLogId, acceptedAt };
    if (activeDoorRequest) {
      finish(order.requestId, ackDeadline, "door/ack", { ...ack, result: "ERROR" });
      return;
    }
    activeDoorRequest = order.requestId;
    setTimeout(() => {
      doorState = "OPEN";
      publish("door/state", event({ state: doorState }));
      finish(order.requestId, ackDeadline, "door/ack", { ...ack, result: "UNLOCKED" });
      setTimeout(() => {
        doorState = "CLOSED";
        activeDoorRequest = undefined;
        publish("door/state", event({ state: doorState }));
      }, order.unlockDurationMs + doorOpeningMs);
    }, doorOpeningMs);
  } catch {
    console.warn("Simulador MQTT recebeu comando inválido.");
  }
});

setInterval(() => publish("status", event()), 10_000).unref();
setInterval(() => {
  if (detected) publish("presence", event({ detected }));
  const now = Date.now();
  for (const [id, timeout] of pendingReads) if (timeout <= now) pendingReads.delete(id);
  for (const [id, outcome] of completed) if (outcome.expiresAt <= now) completed.delete(id);
}, 2_000).unref();

// Controle de ensaio acessível somente por docker compose exec.
const control = createServer((req, res) => {
  const address = new URL(req.url ?? "/", "http://localhost");
  let status = 204;
  if (req.method !== "POST") {
    status = 405;
  } else if (address.pathname === "/presence") {
    detected = address.searchParams.get("detected") !== "false";
    publish("presence", event({ detected }));
  } else if (address.pathname === "/read") {
    const tag = uidSchema.safeParse(address.searchParams.get("uid") ?? uid);
    if (!ready) status = 503;
    else if (!tag.success) status = 400;
    else {
      const requestId = randomUUID();
      pendingReads.set(requestId, Date.now() + accessWindowMs);
      publish("access/request", event({ requestId, uid: tag.data }));
    }
  } else if (address.pathname === "/tag") {
    const nextUid = address.searchParams.get("uid");
    if (nextUid && uidSchema.safeParse(nextUid).success) uid = nextUid;
    else status = 400;
  } else if (address.pathname === "/write-fault") {
    const fault = address.searchParams.get("mode");
    if (fault === "FAILED" || fault === "TIMEOUT") writeFault = fault;
    else if (fault === "off") writeFault = undefined;
    else status = 400;
  } else {
    status = 404;
  }
  res.writeHead(status).end();
});
control.listen(8090, "127.0.0.1");

process.once("SIGTERM", () => {
  control.close();
  client.end(true, () => process.exit(0));
});
