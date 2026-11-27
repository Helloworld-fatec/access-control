import { EventEmitter } from "node:events";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { mqttStatus, startMqtt, stopMqtt } from "./mqtt.service.js";

const { terminalId, db, connect, recordDoorCommandAck } = vi.hoisted(() => ({
  terminalId: "df96f695-a94c-4a4d-9ac5-f90beca3cd71",
  db: {
    mqttDoorCommand: { findMany: vi.fn() }, nfcEnrollment: { findMany: vi.fn() },
    mqttNfcRequest: { findUnique: vi.fn() }, accesslog: { updateMany: vi.fn() },
    qrnonce: { create: vi.fn() },
  },
  connect: vi.fn(),
  recordDoorCommandAck: vi.fn(),
}));
vi.mock("mqtt", () => ({ connect }));
vi.mock("node:fs", async (importOriginal) => ({
  ...await importOriginal<typeof import("node:fs")>(),
  readFileSync: vi.fn(() => Buffer.from("test CA")),
}));
vi.mock("../config/prisma.js", () => ({ prisma: db }));
vi.mock("../config/env.js", () => ({
  env: {
    ESP32_TERMINAL_ID: terminalId, MQTT_URL: "mqtts://test",
    MQTT_CA_FILE: "test-ca.crt", MQTT_BACKEND_PASSWORD: "test-password",
  },
}));
vi.mock("./door-unlock.service.js", () => ({ recordDoorCommandAck }));

const logId = "02e13323-bb93-4c82-8e35-06c7e62704fc";
const commandId = "7b1e029e-a24c-4322-a20c-61fc42542d47";
const issuedAt = new Date("2026-11-23T12:01:00Z");
const command = {
  id: commandId, accessLogId: logId, terminalId, issuedAt,
  expiresAt: new Date("2026-11-23T12:01:05Z"), accessLog: { method: "QR" },
};
const client = Object.assign(new EventEmitter(), {
  connected: false,
  subscribe: vi.fn(),
  publishAsync: vi.fn(),
  endAsync: vi.fn(),
});

beforeEach(() => {
  vi.resetAllMocks();
  vi.useFakeTimers();
  vi.setSystemTime(issuedAt);
  client.removeAllListeners();
  client.connected = true;
  client.subscribe.mockImplementation((topics: string[], _options, callback) =>
    callback(null, topics.map(() => ({ qos: 1 }))));
  connect.mockReturnValue(client);
  db.mqttDoorCommand.findMany.mockResolvedValue([command]);
  db.nfcEnrollment.findMany.mockResolvedValue([]);
  startMqtt();
  client.emit("connect");
});

afterEach(async () => {
  await stopMqtt();
  vi.useRealTimers();
});

describe("Ponte MQTT de abertura", () => {
  it("emite um único QR do OLED e repete a matriz para pedido duplicado", async () => {
    const topic = `access/v1/terminals/${terminalId}/qr/request`;
    const payload = Buffer.from(JSON.stringify({
      schemaVersion: 1, terminalId, eventId: commandId, requestId: logId,
      occurredAt: issuedAt.toISOString(),
    }));
    client.emit("message", topic, payload, { retain: true });
    client.emit("message", topic, payload, { retain: false });
    client.emit("message", topic, payload, { retain: false });
    await vi.advanceTimersByTimeAsync(1);

    expect(db.qrnonce.create).toHaveBeenCalledTimes(1);
    expect(client.publishAsync).toHaveBeenCalledTimes(2);
    const [responseTopic, response, options] = client.publishAsync.mock.calls[0]!;
    expect(responseTopic).toBe(`access/v1/terminals/${terminalId}/qr/display`);
    expect(JSON.parse(response)).toMatchObject({
      terminalId, requestId: logId, refreshAfterSeconds: 10,
      expiresAt: new Date(issuedAt.getTime() + 20000).toISOString(),
      bitmap: expect.stringMatching(/^[a-f0-9]{110}(00|80)$/),
    });
    expect(options).toMatchObject({ qos: 1, retain: false });
    expect(client.publishAsync.mock.calls[1]![1]).toBe(response);
  });

  it("publica o comando e encaminha a confirmação correlacionada", async () => {
    await vi.advanceTimersByTimeAsync(500);
    const [topic, payload, options] = client.publishAsync.mock.calls[0]!;
    expect(topic).toBe(`access/v1/terminals/${terminalId}/door/command`);
    expect(JSON.parse(payload)).toMatchObject({
      terminalId, requestId: logId, eventId: commandId, accessLogId: logId,
      method: "QR", unlockDurationMs: 3000, expiresAt: command.expiresAt.toISOString(),
    });
    expect(options).toMatchObject({ qos: 1, retain: false });

    const ack = {
      schemaVersion: 1, terminalId, requestId: logId, accessLogId: logId,
      eventId: commandId, result: "UNLOCKED", acceptedAt: issuedAt.toISOString(),
      occurredAt: new Date().toISOString(),
    };
    const ackTopic = `access/v1/terminals/${terminalId}/door/ack`;
    client.emit("message", ackTopic, Buffer.from(JSON.stringify({ ...ack, terminalId: logId })), { retain: false });
    client.emit("message", ackTopic, Buffer.from(JSON.stringify(ack)), { retain: true });
    client.emit("message", ackTopic, Buffer.from(JSON.stringify(ack)), { retain: false });
    expect(recordDoorCommandAck).toHaveBeenCalledExactlyOnceWith(ack);
  });

  it("refaz as assinaturas após reconexão e descarta comandos vencidos", async () => {
    expect(mqttStatus()).toBe("connected");
    client.connected = false;
    client.emit("close");
    expect(mqttStatus()).toBe("disconnected");
    await vi.advanceTimersByTimeAsync(6_000);
    expect(client.publishAsync).not.toHaveBeenCalled();

    client.connected = true;
    client.emit("connect");
    await vi.advanceTimersByTimeAsync(500);
    expect(mqttStatus()).toBe("connected");
    expect(client.subscribe).toHaveBeenCalledTimes(2);
    expect(client.publishAsync).not.toHaveBeenCalled();
  });

  it("publica checkout com o UUID da visita como identificador de correlação", async () => {
    db.mqttDoorCommand.findMany.mockResolvedValue([{
      ...command, accessLogId: null, accessLog: null, checkoutVisitId: logId,
    }]);
    await vi.advanceTimersByTimeAsync(500);
    expect(client.publishAsync).toHaveBeenCalledTimes(1);
    const [topic, payload, options] = client.publishAsync.mock.calls[0]!;
    expect(topic).toBe(`access/v1/terminals/${terminalId}/door/command`);
    expect(JSON.parse(payload)).toMatchObject({
      terminalId, eventId: commandId, requestId: logId, accessLogId: logId,
      method: "CHECKOUT_POKEMON", unlockDurationMs: 3000,
    });
    expect(options).toMatchObject({ qos: 1, retain: false });
  });

  it("aceita o ACK NFC após o prazo da solicitação somente se a ordem foi aceita a tempo", async () => {
    vi.setSystemTime(new Date("2026-11-23T12:01:09.120Z"));
    db.mqttNfcRequest.findUnique.mockResolvedValue({
      expiresAt: command.expiresAt,
      decision: { accessLogId: logId, granted: true, decidedAt: issuedAt.toISOString() },
    });
    db.accesslog.updateMany.mockResolvedValue({ count: 1 });
    const ack = {
      schemaVersion: 1, terminalId, requestId: commandId, accessLogId: logId,
      eventId: logId, result: "UNLOCKED", occurredAt: new Date().toISOString(),
    };
    const topic = `access/v1/terminals/${terminalId}/door/ack`;
    client.emit("message", topic, Buffer.from(JSON.stringify({
      ...ack, acceptedAt: command.expiresAt.toISOString(),
    })), { retain: false });
    await Promise.resolve();
    expect(db.accesslog.updateMany).not.toHaveBeenCalled();

    client.emit("message", topic, Buffer.from(JSON.stringify({
      ...ack, acceptedAt: "2026-11-23T12:01:04Z",
    })), { retain: false });
    await Promise.resolve();
    expect(db.accesslog.updateMany).toHaveBeenCalledExactlyOnceWith(expect.objectContaining({
      data: { commandAcked: true },
    }));
  });
});
