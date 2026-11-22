import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { recordEsp32NfcAccess, recordEsp32NfcUnlockAck } from "./access.controller.js";

const { terminalId, db } = vi.hoisted(() => ({
  terminalId: "df96f695-a94c-4a4d-9ac5-f90beca3cd71",
  db: {
    terminal: { findUnique: vi.fn() },
    nfccredential: { findUnique: vi.fn() },
    user: { findUnique: vi.fn() },
    authorization: { findMany: vi.fn(), updateMany: vi.fn() },
    accesslog: { create: vi.fn(), updateMany: vi.fn() },
    mqttNfcRequest: { createMany: vi.fn(), findUnique: vi.fn(), update: vi.fn() },
    $transaction: vi.fn(),
  },
}));
vi.mock("../config/env.js", () => ({ env: { ESP32_TERMINAL_ID: terminalId, JWT_SECRET: "test-secret" } }));
vi.mock("../config/prisma.js", () => ({ prisma: db }));

const topic = `access/v1/terminals/${terminalId}/access/request`;
const payload = { terminalId, credential: { type: "NFC", value: "a1b2c3" } };

beforeEach(() => {
  vi.resetAllMocks();
  vi.setSystemTime(new Date("2026-11-21T15:00:00Z"));
  db.$transaction.mockImplementation((work) => work(db));
  db.terminal.findUnique.mockResolvedValue({ id: terminalId, locationId: "porta" });
});

afterEach(() => vi.useRealTimers());

describe("NFC do ESP32", () => {
  it("usa o local da placa e registra a autorização concedida com seu UUID", async () => {
    db.nfccredential.findUnique.mockResolvedValue({ status: "ACTIVE", userId: "morador" });
    db.user.findUnique.mockResolvedValue({ id: "morador", active: true, name: "Morador" });
    db.authorization.findMany.mockResolvedValue([{
      id: "autorizacao", status: "ACTIVE", startDate: new Date("2026-11-21"),
      endDate: new Date("2026-11-22"), startTime: "00:00", endTime: "23:59",
      maxUses: 1, usedCount: 0,
    }]);
    db.authorization.updateMany.mockResolvedValue({ count: 1 });
    db.mqttNfcRequest.createMany.mockResolvedValueOnce({ count: 1 }).mockResolvedValue({ count: 0 });
    db.mqttNfcRequest.update.mockImplementation(({ data }) => {
      const { fingerprint } = db.mqttNfcRequest.createMany.mock.calls[0]![0].data;
      db.mqttNfcRequest.findUnique.mockResolvedValue({ ...data, fingerprint });
    });
    const request = {
      requestId: "a1a84eb7-ba8f-4e29-bb6a-a373ad0bcda0",
      occurredAt: "2026-11-21T15:00:00Z",
      expiresAt: new Date("2026-11-21T15:00:05Z"),
    };
    const outcome = await recordEsp32NfcAccess(topic, payload, request);

    expect(outcome).toMatchObject({ granted: true, accessLogId: expect.any(String) });
    expect(db.nfccredential.findUnique).toHaveBeenCalledWith(expect.objectContaining({
      where: { codeHex: "A1B2C3" },
    }));
    expect(db.authorization.findMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { locationId: "porta", userId: "morador" },
    }));
    expect(db.accesslog.create).toHaveBeenCalledWith({ data: expect.objectContaining({
      id: outcome?.accessLogId, terminalId, authorizationId: "autorizacao",
      method: "NFC", result: "GRANTED", nfcUid: null,
    }) });
    await expect(recordEsp32NfcAccess(topic, payload, request)).resolves.toEqual(outcome);
    await expect(recordEsp32NfcAccess(topic, {
      ...payload, credential: { type: "NFC", value: "000000" },
    }, request)).resolves.toBeNull();
    expect(db.accesslog.create).toHaveBeenCalledTimes(1);
    expect(db.authorization.updateMany).toHaveBeenCalledTimes(1);
  });

  it("registra a negativa no terminal da placa quando a tag ainda está pendente", async () => {
    db.nfccredential.findUnique.mockResolvedValue({ status: "PENDING", userId: "morador" });
    const outcome = await recordEsp32NfcAccess(topic, payload);
    expect(outcome).toMatchObject({ granted: false, accessLogId: expect.any(String) });
    expect(db.accesslog.create).toHaveBeenCalledWith({ data: expect.objectContaining({
      id: outcome?.accessLogId, terminalId, method: "NFC", result: "DENIED", reason: "INVALID_CREDENTIAL",
    }) });
    expect(db.authorization.updateMany).not.toHaveBeenCalled();
  });

  it("recusa um tópico divergente antes de consultar o banco", async () => {
    await expect(recordEsp32NfcAccess(topic.replace(terminalId, "outro"), payload))
      .rejects.toMatchObject({ code: "TERMINAL_MISMATCH" });
    expect(db.$transaction).not.toHaveBeenCalled();
  });

  it("vincula a confirmação à concessão NFC da mesma placa", async () => {
    const accessLogId = "01e13323-bb93-4c82-8e35-06c7e62704fc";
    db.accesslog.updateMany.mockResolvedValue({ count: 1 });
    await expect(recordEsp32NfcUnlockAck(
      `access/v1/terminals/${terminalId}/door/ack`,
      { terminalId, accessLogId, result: "UNLOCKED" },
    )).resolves.toBe(true);
    expect(db.accesslog.updateMany).toHaveBeenCalledWith({
      where: { id: accessLogId, terminalId, method: "NFC", result: "GRANTED" },
      data: { commandAcked: true },
    });
  });
});
