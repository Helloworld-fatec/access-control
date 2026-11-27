import { createHash } from "node:crypto";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import express from "express";
import jwt from "jsonwebtoken";
import request from "supertest";

const txMock = vi.hoisted(() => ({
  qrNonce: { findUnique: vi.fn(), updateMany: vi.fn() },
  user: { findUnique: vi.fn() },
  authorization: { findMany: vi.fn(), updateMany: vi.fn() },
  accessLog: { create: vi.fn() },
}));
const prismaMock = vi.hoisted(() => ({ $transaction: vi.fn() }));
const unlock = vi.hoisted(() => vi.fn());
vi.mock("../config/prisma.js", () => ({ prisma: prismaMock }));
vi.mock("../services/door-unlock.service.js", () => ({ requestDoorUnlock: unlock }));

import { accessRoutes } from "../routes/access.routes.js";
import { errorHandler } from "../middlewares/error.middleware.js";

const app = express();
app.use(express.json());
app.use("/access", accessRoutes);
app.use(errorHandler);

const USER = "33333333-3333-4333-8333-333333333333";
const LOCATION = "44444444-4444-4444-8444-444444444444";
const TERMINAL = "11111111-1111-4111-8111-111111111111";
const TOKEN = "token-do-qr-com-bastante-entropia-123456789";
const bearer = () => `Bearer ${jwt.sign({ role: "RESIDENT" }, process.env.JWT_SECRET as string, { subject: USER, expiresIn: "1h" })}`;
const post = (body: Record<string, unknown>, auth: string | null = bearer()) => {
  const r = request(app).post("/access/qr/consume");
  if (auth) r.set("Authorization", auth);
  return r.send(body);
};
const consume = (token: string = TOKEN, auth: string | null = bearer()) => post({ token }, auth);

const authorization = (over: Record<string, unknown> = {}) => ({
  id: "auth-1", userId: USER, locationId: LOCATION, status: "ACTIVE",
  startDate: new Date("2026-11-01T00:00:00.000Z"), endDate: new Date("2026-12-31T00:00:00.000Z"),
  startTime: "08:00", endTime: "20:00", maxUses: null, usedCount: 0, createdAt: new Date(), ...over,
});
const expectLog = (data: Record<string, unknown>) => {
  expect(txMock.accessLog.create).toHaveBeenCalledTimes(1);
  expect(txMock.accessLog.create.mock.calls[0][0].data).toMatchObject(data);
};

beforeEach(() => {
  vi.clearAllMocks();
  vi.useFakeTimers({ toFake: ["Date"] });
  vi.setSystemTime(new Date("2026-11-19T18:00:00.000Z")); // 15:00 em São Paulo
  prismaMock.$transaction.mockImplementation(async (cb: (tx: typeof txMock) => unknown) => cb(txMock));
  txMock.qrNonce.findUnique.mockResolvedValue({ nonce: "h", terminalId: TERMINAL, expiresAt: new Date("2026-11-19T18:04:00.000Z"), terminal: { id: TERMINAL, locationId: LOCATION } });
  txMock.qrNonce.updateMany.mockResolvedValue({ count: 1 });
  txMock.user.findUnique.mockResolvedValue({ id: USER, active: true });
  txMock.authorization.findMany.mockResolvedValue([authorization()]);
  txMock.authorization.updateMany.mockResolvedValue({ count: 1 });
  txMock.accessLog.create.mockResolvedValue({ id: "log-1" });
});
afterEach(() => vi.useRealTimers());

describe("POST /access/qr/consume: credenciais", () => {
  it("sem token de login: 401", async () => {
    const r = await consume(TOKEN, null);
    expect(r.status).toBe(401);
    expect(r.body.error.code).toBe("UNAUTHORIZED");
    expect(prismaMock.$transaction).not.toHaveBeenCalled();
  });

  it("token de login inválido: 401", async () => {
    const r = await consume(TOKEN, "Bearer isto.nao.e.jwt");
    expect(r.status).toBe(401);
    expect(r.body.error.code).toBe("INVALID_TOKEN");
  });

  it("token de login vencido: 401", async () => {
    const vencido = jwt.sign({ role: "RESIDENT" }, process.env.JWT_SECRET as string, { subject: USER, expiresIn: -10 });
    const r = await consume(TOKEN, `Bearer ${vencido}`);
    expect(r.status).toBe(401);
  });

  it("token assinado com outro segredo: 401", async () => {
    const falso = jwt.sign({ role: "ADMIN" }, "outro-segredo-qualquer-com-mais-de-32-caracteres", { subject: USER });
    expect((await consume(TOKEN, `Bearer ${falso}`)).status).toBe(401);
  });

  it.each([[{}], [{ token: "" }], [{ token: 123 }]])("QR ausente, vazio ou não textual (%j): 400", async (body) => {
    const r = await post(body);
    expect(r.status).toBe(400);
    expect(prismaMock.$transaction).not.toHaveBeenCalled();
  });

  it("QR desconhecido: 401 INVALID_CREDENTIAL, sem liberar a porta", async () => {
    txMock.qrNonce.findUnique.mockResolvedValue(null);
    const r = await consume();
    expect(r.status).toBe(401);
    expect(r.body.error.code).toBe("INVALID_CREDENTIAL");
    expect(unlock).not.toHaveBeenCalled();
  });

  it("o QR é procurado pelo hash SHA-256, nunca em texto puro", async () => {
    await consume();
    const where = txMock.qrNonce.findUnique.mock.calls[0][0].where;
    expect(where.nonce).toBe(createHash("sha256").update(TOKEN).digest("hex"));
    expect(JSON.stringify(where)).not.toContain(TOKEN);
  });
});

describe("POST /access/qr/consume: decisão e registro", () => {
  it("libera, registra GRANTED (QR), usa a autorização e pede a abertura da porta", async () => {
    const r = await consume();
    expect(r.status).toBe(200);
    expect(r.body).toMatchObject({ result: "GRANTED", terminalId: TERMINAL, authorizationId: "auth-1" });
    expectLog({ userId: USER, terminalId: TERMINAL, authorizationId: "auth-1", method: "QR", result: "GRANTED", reason: null });
    expect(unlock).toHaveBeenCalledWith(expect.objectContaining({ terminalId: TERMINAL, userId: USER, accessLogId: "log-1", method: "QR" }));
  });

  it("o QR só pode ser usado uma vez: o consumo é atômico (só consome se ainda não foi consumido)", async () => {
    await consume();
    expect(txMock.qrNonce.updateMany.mock.calls[0][0].where).toMatchObject({ consumedAt: null });
  });

  it("QR já usado: 403 REPLAYED_CREDENTIAL, registrado e sem abrir a porta", async () => {
    txMock.qrNonce.updateMany.mockResolvedValue({ count: 0 });
    const r = await consume();
    expect(r.status).toBe(403);
    expect(r.body.reason).toBe("REPLAYED_CREDENTIAL");
    expectLog({ result: "DENIED", reason: "REPLAYED_CREDENTIAL", method: "QR" });
    expect(unlock).not.toHaveBeenCalled();
  });

  it("QR vencido (mais de 5 min): 403 EXPIRED_CREDENTIAL", async () => {
    txMock.qrNonce.findUnique.mockResolvedValue({ nonce: "h", terminalId: TERMINAL, expiresAt: new Date("2026-11-19T17:59:59.000Z"), terminal: { id: TERMINAL, locationId: LOCATION } });
    const r = await consume();
    expect(r.status).toBe(403);
    expect(r.body.reason).toBe("EXPIRED_CREDENTIAL");
    expectLog({ result: "DENIED", reason: "EXPIRED_CREDENTIAL" });
    expect(unlock).not.toHaveBeenCalled();
  });

  it("usuário inativo: USER_INACTIVE", async () => {
    txMock.user.findUnique.mockResolvedValue({ id: USER, active: false });
    const r = await consume();
    expect(r.body.reason).toBe("USER_INACTIVE");
    expectLog({ result: "DENIED", reason: "USER_INACTIVE" });
  });

  it("sem autorização no local do terminal: NO_AUTHORIZATION", async () => {
    txMock.authorization.findMany.mockResolvedValue([]);
    const r = await consume();
    expect(r.body.reason).toBe("NO_AUTHORIZATION");
    expect(txMock.authorization.findMany.mock.calls[0][0].where).toEqual({ userId: USER, locationId: LOCATION });
    expectLog({ result: "DENIED", reason: "NO_AUTHORIZATION" });
  });

  it("só autorizações canceladas: AUTHORIZATION_CANCELED", async () => {
    txMock.authorization.findMany.mockResolvedValue([authorization({ status: "CANCELED" })]);
    const r = await consume();
    expect(r.body.reason).toBe("AUTHORIZATION_CANCELED");
    expectLog({ authorizationId: "auth-1", reason: "AUTHORIZATION_CANCELED" });
  });

  it("fora do período: OUTSIDE_PERIOD", async () => {
    txMock.authorization.findMany.mockResolvedValue([authorization({ endDate: new Date("2026-11-18T00:00:00.000Z") })]);
    expect((await consume()).body.reason).toBe("OUTSIDE_PERIOD");
  });

  it("fora do horário: OUTSIDE_SCHEDULE", async () => {
    txMock.authorization.findMany.mockResolvedValue([authorization({ startTime: "16:00", endTime: "20:00" })]);
    const r = await consume();
    expect(r.body.reason).toBe("OUTSIDE_SCHEDULE");
    expectLog({ result: "DENIED", reason: "OUTSIDE_SCHEDULE" });
  });

  it("usos esgotados: USES_EXHAUSTED", async () => {
    txMock.authorization.findMany.mockResolvedValue([authorization({ maxUses: 2, usedCount: 2 })]);
    const r = await consume();
    expect(r.body.reason).toBe("USES_EXHAUSTED");
    expect(txMock.authorization.updateMany).not.toHaveBeenCalled();
  });

  it("corrida no último uso (outro acesso incrementou antes): USES_EXHAUSTED", async () => {
    txMock.authorization.findMany.mockResolvedValue([authorization({ maxUses: 2, usedCount: 1 })]);
    txMock.authorization.updateMany.mockResolvedValue({ count: 0 });
    const r = await consume();
    expect(r.status).toBe(403);
    expect(r.body.reason).toBe("USES_EXHAUSTED");
    expect(unlock).not.toHaveBeenCalled();
  });

  it("negativas devolvem o id do registro, para auditoria", async () => {
    txMock.authorization.findMany.mockResolvedValue([]);
    const r = await consume();
    expect(r.body).toMatchObject({ result: "DENIED", accessLogId: "log-1" });
  });
});
