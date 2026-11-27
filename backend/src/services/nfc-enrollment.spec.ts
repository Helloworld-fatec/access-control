import { createHash } from "node:crypto";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { recordEnrollmentAck } from "./nfc-enrollment.service.js";

const db = vi.hoisted(() => ({
  $transaction: vi.fn(),
  $queryRaw: vi.fn(),
  nfcEnrollment: { findUnique: vi.fn(), updateMany: vi.fn(), update: vi.fn() },
  nfccredential: { findUnique: vi.fn(), update: vi.fn() },
  nfctag: { createMany: vi.fn(), findUnique: vi.fn() },
}));
vi.mock("../config/prisma.js", () => ({ prisma: db }));

const requestId = "c1a84eb7-ba8f-4e29-bb6a-a373ad0bcda0";
const terminalId = "df96f695-a94c-4a4d-9ac5-f90beca3cd71";
const uid = "04A32F1B";
const codeHex = "00A3F9";
const ack = {
  schemaVersion: 1,
  eventId: "ab1e029e-a24c-4322-a20c-61fc42542d47",
  requestId, terminalId, uid, result: "WRITTEN",
  occurredAt: "2026-11-23T11:59:24Z",
  readbackSha256: createHash("sha256").update(Buffer.from(codeHex, "hex")).digest("hex"),
};

beforeEach(() => {
  vi.resetAllMocks();
  vi.setSystemTime(new Date(ack.occurredAt));
  db.$transaction.mockImplementation((work) => work(db));
  db.$queryRaw.mockResolvedValue([{ id: "user" }]);
  db.nfcEnrollment.findUnique.mockResolvedValue({
    id: requestId, userId: "user", terminalId, expectedUid: uid, status: "PENDING",
    createdAt: new Date("2026-11-23T11:59:20Z"), expiresAt: new Date("2026-11-23T11:59:50Z"),
  });
  db.nfcEnrollment.updateMany.mockResolvedValue({ count: 1 });
  db.nfccredential.findUnique.mockResolvedValue({ codeHex, status: "PENDING" });
  db.nfctag.findUnique.mockResolvedValue({ id: "tag", userId: "user", active: true });
});

afterEach(() => vi.useRealTimers());

describe("Confirmação MQTT de gravação NFC", () => {
  it("ativa a credencial e vincula a tag após releitura válida", async () => {
    await recordEnrollmentAck(ack);
    expect(db.nfctag.createMany).toHaveBeenCalledWith({
      data: { uid, userId: "user" }, skipDuplicates: true,
    });
    expect(db.nfccredential.update).toHaveBeenCalledWith({
      where: { userId: "user" }, data: { status: "ACTIVE", tagId: "tag" },
    });
    expect(db.nfcEnrollment.update).toHaveBeenLastCalledWith({
      where: { id: requestId }, data: { status: "WRITTEN", reason: null },
    });
  });

  it("mantém a credencial pendente quando a releitura diverge", async () => {
    await recordEnrollmentAck({ ...ack, readbackSha256: "0".repeat(64) });
    expect(db.nfcEnrollment.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      data: { status: "FAILED", reason: "READBACK_MISMATCH" },
    }));
    expect(db.nfctag.createMany).not.toHaveBeenCalled();
    expect(db.nfccredential.update).not.toHaveBeenCalled();
  });

  it("ignora confirmação de outro terminal ou de pedido já finalizado", async () => {
    await recordEnrollmentAck({ ...ack, terminalId: requestId });
    db.nfcEnrollment.updateMany.mockResolvedValue({ count: 0 });
    await recordEnrollmentAck(ack);
    expect(db.nfcEnrollment.updateMany).toHaveBeenCalledTimes(1);
    expect(db.nfccredential.update).not.toHaveBeenCalled();
  });

  it("não ativa se o prazo venceu no recebimento", async () => {
    vi.setSystemTime(new Date("2026-11-23T11:59:51Z"));
    db.nfcEnrollment.updateMany.mockResolvedValue({ count: 0 });
    await recordEnrollmentAck(ack);
    expect(db.nfcEnrollment.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: requestId, status: "PENDING", expiresAt: { gt: new Date() } },
    }));
    expect(db.nfccredential.update).not.toHaveBeenCalled();
  });
});
