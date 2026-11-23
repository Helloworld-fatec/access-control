import { createHash } from "node:crypto";
import jwt from "jsonwebtoken";
import request from "supertest";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { env } from "../config/env.js";
import { hashTerminalKey } from "../config/terminal-key.js";
import { app } from "../index.js";
import { requestDoorUnlock } from "../services/door-unlock.service.js";
import { issueQrToken } from "../services/qr-token.service.js";

const db = vi.hoisted(() => ({
  terminal: { findUnique: vi.fn(), update: vi.fn() },
  qrnonce: { create: vi.fn(), findUnique: vi.fn(), updateMany: vi.fn() },
  user: { findUnique: vi.fn() },
  authorization: { findMany: vi.fn(), updateMany: vi.fn() },
  accesslog: { create: vi.fn() },
  $transaction: vi.fn(),
}));
vi.mock("../config/prisma.js", () => ({ prisma: db }));
vi.mock("../services/door-unlock.service.js", () => ({ requestDoorUnlock: vi.fn() }));

const api = request(app);
const terminal = { id: "qr-terminal", locationId: "qr-location" };
const userId = "qr-user";
const key = "ab12ef";
const start = new Date("2026-11-21T15:00:00Z");
const authorization = {
  id: "qr-auth",
  status: "ACTIVE",
  startDate: new Date("2026-11-21"),
  endDate: new Date("2026-11-21"),
  startTime: "08:00",
  endTime: "18:00",
  usedCount: 0,
  maxUses: 1,
};

interface Nonce {
  nonce: string;
  terminalId: string;
  expiresAt: Date;
  consumedAt: Date | null;
  terminal: typeof terminal;
}

const nonces = new Map<string, Nonce>();
const hash = (token: string) => createHash("sha256").update(token).digest("hex");
const issue = (credential = key) =>
  api.post("/api/terminals/me/qr").set("x-terminal-key", credential);
const consume = (token: string) => api.post("/api/access/qr/consume")
  .set("Authorization", `Bearer ${jwt.sign({ role: "USER" }, env.JWT_SECRET, { subject: userId })}`)
  .send({ token });
const advance = (seconds: number) => vi.setSystemTime(start.getTime() + seconds * 1000);

beforeEach(() => {
  vi.resetAllMocks();
  advance(0);
  nonces.clear();
  db.terminal.findUnique.mockImplementation(({ where }) =>
    where.apiKeyHash === hashTerminalKey(key) ? terminal : null,
  );
  db.qrnonce.create.mockImplementation(({ data }) => {
    const nonce = { ...data, terminal, consumedAt: null };
    nonces.set(data.nonce, nonce);
    return nonce;
  });
  db.qrnonce.findUnique.mockImplementation(({ where }) => nonces.get(where.nonce));
  db.qrnonce.updateMany.mockImplementation(({ where, data }) => {
    const nonce = nonces.get(where.nonce);
    if (!nonce || nonce.consumedAt) return { count: 0 };
    nonce.consumedAt = data.consumedAt;
    return { count: 1 };
  });
  db.$transaction.mockImplementation((run) => run(db));
  db.user.findUnique.mockResolvedValue({ id: userId, active: true });
  db.authorization.findMany.mockResolvedValue([authorization]);
  db.authorization.updateMany.mockResolvedValue({ count: 1 });
  db.accesslog.create.mockResolvedValue({ id: "qr-log" });
});

afterEach(() => vi.useRealTimers());

describe("emissao e consumo oficial de QR", () => {
  it("consome o token compacto do OLED com a mesma autorização e bloqueia reuso", async () => {
    const { token } = await issueQrToken(terminal.id, true);
    expect(token).toMatch(/^Q[A-Z0-9]{19}$/);
    expect((await consume(token)).body.result).toBe("GRANTED");
    expect((await consume(token)).body.reason).toBe("REPLAYED_CREDENTIAL");
    expect(requestDoorUnlock).toHaveBeenCalledExactlyOnceWith({
      terminalId: terminal.id, accessLogId: "qr-log", userId, method: "QR",
    });
  });

  it("emite o JSON do scanner a cada dez segundos por mais de um minuto", async () => {
    const tokens = new Set<string>();
    for (let seconds = 0; seconds <= 70; seconds += 10) {
      advance(seconds);
      const { status, body } = await issue();
      expect(status).toBe(200);
      expect(body).toEqual({
        payload: { v: 1, token: expect.stringMatching(/^[A-Za-z0-9_-]{43}$/) },
        expiresAt: new Date(start.getTime() + (seconds + 20) * 1000).toISOString(),
        refreshAfterSeconds: 10,
      });
      tokens.add(body.payload.token);
      expect(nonces.get(hash(body.payload.token))?.terminalId).toBe(terminal.id);
    }
    expect(tokens.size).toBe(8);
  });

  it("aceita o token anterior depois da rotacao e rejeita o reuso", async () => {
    const previous = await issue();
    advance(10);
    const next = await issue();
    expect(next.body.payload.token).not.toBe(previous.body.payload.token);

    advance(19);
    const accepted = await consume(previous.body.payload.token);
    expect(accepted.status).toBe(200);
    expect(accepted.body).toMatchObject({ result: "GRANTED", terminalId: terminal.id });

    const replay = await consume(previous.body.payload.token);
    expect(replay.status).toBe(403);
    expect(replay.body.reason).toBe("REPLAYED_CREDENTIAL");
    expect(db.authorization.updateMany).toHaveBeenCalledTimes(1);
    expect(db.accesslog.create).toHaveBeenCalledTimes(2);
    expect(requestDoorUnlock).toHaveBeenCalledExactlyOnceWith({
      terminalId: terminal.id, accessLogId: "qr-log", userId, method: "QR",
    });
  });

  it("recusa um usuario sem autorizacao e registra a decisao", async () => {
    db.authorization.findMany.mockResolvedValue([]);
    const { body } = await issue();
    const denied = await consume(body.payload.token);

    expect(denied.status).toBe(403);
    expect(denied.body).toMatchObject({ result: "DENIED", reason: "NO_AUTHORIZATION" });
    expect(db.accesslog.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ terminalId: terminal.id, userId, result: "DENIED" }),
    });
    expect(db.authorization.updateMany).not.toHaveBeenCalled();
  });

  it("recusa um token ao atingir vinte segundos de idade", async () => {
    const { body } = await issue();
    advance(20);
    const denied = await consume(body.payload.token);

    expect(denied.status).toBe(403);
    expect(denied.body.reason).toBe("EXPIRED_CREDENTIAL");
    expect(db.authorization.updateMany).not.toHaveBeenCalled();
  });

  it("exige a chave do terminal na emissao e JWT de usuario no consumo", async () => {
    const rejected = await issue("ffffff");
    expect(rejected.status).toBe(401);
    expect(db.qrnonce.create).not.toHaveBeenCalled();

    const { body } = await issue();
    const response = await api.post("/api/access/qr/consume")
      .set("x-terminal-key", key)
      .send({ token: body.payload.token });
    expect(response.status).toBe(401);
    expect(db.$transaction).not.toHaveBeenCalled();
  });
});
