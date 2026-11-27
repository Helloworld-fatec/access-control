import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { recordDoorCommandAck, requestDoorUnlock } from "./door-unlock.service.js";

const { target, db } = vi.hoisted(() => ({
  target: "df96f695-a94c-4a4d-9ac5-f90beca3cd71",
  db: {
    accesslog: { findFirst: vi.fn(), update: vi.fn() },
    terminal: { findFirst: vi.fn() },
    mqttDoorCommand: { createMany: vi.fn(), updateMany: vi.fn() },
    $transaction: vi.fn(),
  },
}));
vi.mock("../config/env.js", () => ({ env: { MQTT_URL: "mqtts://test", ESP32_TERMINAL_ID: target } }));
vi.mock("../config/prisma.js", () => ({ prisma: db }));

const logId = "02e13323-bb93-4c82-8e35-06c7e62704fc";
const request = { terminalId: "celular", userId: "morador", accessLogId: logId, method: "QR" } as const;
const issuedAt = new Date("2026-11-23T12:01:00Z");
const expiresAt = new Date("2026-11-23T12:01:05Z");

beforeEach(() => {
  vi.resetAllMocks();
  vi.setSystemTime(issuedAt);
  db.accesslog.findFirst.mockResolvedValue({ createdAt: issuedAt, terminal: { locationId: "portaria" } });
  db.terminal.findFirst.mockResolvedValue({ id: target });
  db.$transaction.mockImplementation((run) => run(db));
  db.mqttDoorCommand.updateMany.mockResolvedValue({ count: 1 });
});
afterEach(() => vi.useRealTimers());

describe("Comando de abertura por MQTT", () => {
  it.each(["QR", "FACE"] as const)("agenda a concessão %s para a placa do mesmo local", async (method) => {
    await requestDoorUnlock({ ...request, method });
    expect(db.accesslog.findFirst).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: logId, method, result: "GRANTED", terminalId: request.terminalId, userId: request.userId },
    }));
    expect(db.terminal.findFirst).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: target, locationId: "portaria" },
    }));
    expect(db.mqttDoorCommand.createMany).toHaveBeenCalledWith({
      data: { accessLogId: logId, terminalId: target, issuedAt, expiresAt }, skipDuplicates: true,
    });
  });

  it("descarta concessões vencidas ou sem destino no mesmo local", async () => {
    db.terminal.findFirst.mockResolvedValue(null);
    await requestDoorUnlock(request);
    vi.setSystemTime(expiresAt);
    await requestDoorUnlock(request);
    expect(db.mqttDoorCommand.createMany).not.toHaveBeenCalled();
  });

  const ack = {
    terminalId: target, accessLogId: logId, requestId: logId,
    result: "UNLOCKED", acceptedAt: "2026-11-23T12:01:04Z", occurredAt: "2026-11-23T12:01:09.120Z",
  } as const;

  it("confirma a abertura no mesmo registro da concessão", async () => {
    await expect(recordDoorCommandAck(ack)).resolves.toBe(true);
    expect(db.mqttDoorCommand.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({
        accessLogId: logId, terminalId: target, ackResult: null,
        issuedAt: { lte: new Date(ack.acceptedAt) },
        expiresAt: { gt: new Date(ack.acceptedAt) },
      }),
    }));
    expect(db.accesslog.update).toHaveBeenCalledWith({
      where: { id: logId }, data: { commandAcked: true },
    });
  });

  it("rejeita relatos fora da janela de execução ou sem data de aceite", async () => {
    await expect(recordDoorCommandAck({ ...ack, occurredAt: "2026-11-23T12:01:14.001Z" })).resolves.toBe(false);
    await expect(recordDoorCommandAck({ ...ack, acceptedAt: undefined })).resolves.toBe(false);
    await expect(recordDoorCommandAck({ ...ack, occurredAt: "2026-11-23T12:01:03Z" })).resolves.toBe(false);
    expect(db.mqttDoorCommand.updateMany).not.toHaveBeenCalled();
  });

  it("ignora confirmação sem correlação ou já processada", async () => {
    await expect(recordDoorCommandAck({ ...ack, requestId: target })).resolves.toBe(false);
    db.mqttDoorCommand.updateMany.mockResolvedValue({ count: 0 });
    await expect(recordDoorCommandAck(ack)).resolves.toBe(false);
    expect(db.mqttDoorCommand.updateMany).toHaveBeenCalledTimes(2);
    expect(db.accesslog.update).not.toHaveBeenCalled();
  });

  it("confirma o comando de checkout sem alterar registros de entrada", async () => {
    db.mqttDoorCommand.updateMany.mockResolvedValueOnce({ count: 0 }).mockResolvedValueOnce({ count: 1 });
    await expect(recordDoorCommandAck(ack)).resolves.toBe(true);
    expect(db.mqttDoorCommand.updateMany).toHaveBeenLastCalledWith({
      where: {
        checkoutVisitId: logId, terminalId: target, ackResult: null,
        issuedAt: { lte: new Date(ack.acceptedAt) }, expiresAt: { gt: new Date(ack.acceptedAt) },
      },
      data: { ackResult: "UNLOCKED", ackAt: new Date(ack.occurredAt) },
    });
    expect(db.accesslog.update).not.toHaveBeenCalled();
  });
});
