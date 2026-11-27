import jwt from "jsonwebtoken";
import request from "supertest";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { env } from "../config/env.js";
import { app } from "../index.js";

const db = vi.hoisted(() => ({
  user: { findUnique: vi.fn() },
  terminal: { findMany: vi.fn(), findUnique: vi.fn() },
  authorization: { count: vi.fn() },
  $queryRaw: vi.fn(),
  $transaction: vi.fn(),
}));
vi.mock("../config/prisma.js", () => ({ prisma: db }));

const now = new Date("2026-11-22T01:30:00Z");
const subject = "14825695-6cdb-4e40-a33e-94045475eabb";
const api = request(app);
const summary = "/api/dashboard/summary";
const hours = "/api/dashboard/accesses-by-hour";
const status = "/api/terminals/status";
const bearer = (role = "ADMIN") =>
  `Bearer ${jwt.sign({ role }, env.JWT_SECRET, { subject })}`;

beforeEach(() => {
  vi.resetAllMocks();
  vi.setSystemTime(now);
  db.user.findUnique.mockResolvedValue({ role: "ADMIN", active: true });
  db.$queryRaw.mockResolvedValue([]);
  db.authorization.count.mockResolvedValue(0);
  db.terminal.findMany.mockResolvedValue([]);
  db.$transaction.mockImplementation((queries: Promise<unknown>[]) => Promise.all(queries));
});
afterEach(() => vi.useRealTimers());

describe.each([summary, hours, status])("%s requer JWT administrativo", (path) => {
  it("recusa sessão ausente ou perfil sem permissão", async () => {
    expect((await api.get(path)).status).toBe(401);
    db.user.findUnique.mockResolvedValue({ role: "RESIDENT", active: true });
    const response = await api.get(path).set("Authorization", bearer("RESIDENT"));
    expect(response.status).toBe(403);
    expect(response.body.error.code).toBe("FORBIDDEN");
    expect(db.$queryRaw).not.toHaveBeenCalled();
    expect(db.terminal.findMany).not.toHaveBeenCalled();
  });

  it("recusa administrador desativado mesmo com token válido", async () => {
    db.user.findUnique.mockResolvedValue({ role: "ADMIN", active: false });
    expect((await api.get(path).set("Authorization", bearer())).status).toBe(403);
  });
});

it("resume acessos de QR, facial e NFC e calcula as autorizações a partir de hoje em São Paulo", async () => {
  db.$queryRaw.mockResolvedValue([
    { hour: 0, method: "QR", result: "GRANTED", reason: null, count: 2n },
    { hour: 8, method: "FACE", result: "DENIED", reason: "UNKNOWN_FACE", count: 3n },
    { hour: 23, method: "FACE", result: "DENIED", reason: "UNKNOWN_FACE", count: 2n },
    { hour: 23, method: "NFC", result: "DENIED", reason: "OUTSIDE_SCHEDULE", count: 1n },
  ]);
  db.authorization.count.mockResolvedValueOnce(7).mockResolvedValueOnce(3).mockResolvedValueOnce(2);
  const res = await api.get(summary).query({ date: "2026-11-20" }).set("Authorization", bearer());
  expect(res.status).toBe(200);
  expect(res.body).toEqual({
    date: "2026-11-20", granted: 2, denied: 6, denialRate: 0.75,
    byMethod: { QR: 2, FACE: 5, NFC: 1 },
    authorizations: { active: 7, expiringSoon: 3, canceled: 2 },
    topDenialReasons: [
      { reason: "UNKNOWN_FACE", count: 5 },
      { reason: "OUTSIDE_SCHEDULE", count: 1 },
    ],
  });
  expect(db.$queryRaw).toHaveBeenCalledWith(
    expect.anything(), "America/Sao_Paulo", "2026-11-20", "America/Sao_Paulo", "2026-11-20", "America/Sao_Paulo",
  );
  expect(db.authorization.count).toHaveBeenNthCalledWith(2, {
    where: { status: "ACTIVE", endDate: { gte: new Date("2026-11-21"), lte: new Date("2026-11-28") } },
  });
});

it("devolve zeros por padrão e usa a data de São Paulo quando UTC já mudou de dia", async () => {
  const res = await api.get(summary).set("Authorization", bearer());
  expect(res.status).toBe(200);
  expect(res.body).toMatchObject({
    date: "2026-11-21", granted: 0, denied: 0, denialRate: 0,
    byMethod: { QR: 0, FACE: 0, NFC: 0 }, topDenialReasons: [],
  });
  const hourly = await api.get(hours).set("Authorization", bearer());
  expect(hourly.status).toBe(200);
  expect(hourly.body).toEqual(Array.from({ length: 24 }, (_, hour) => ({ hour, granted: 0, denied: 0 })));
});

it("retorna 24 horas em ordem e soma os resultados da mesma hora", async () => {
  db.$queryRaw.mockResolvedValue([
    { hour: 0, method: "QR", result: "GRANTED", reason: null, count: 1n },
    { hour: 0, method: "FACE", result: "GRANTED", reason: null, count: 2n },
    { hour: 23, method: "NFC", result: "DENIED", reason: null, count: 1n },
  ]);
  const res = await api.get(hours).query({ date: "2026-11-21" }).set("Authorization", bearer());
  expect(res.status).toBe(200);
  expect(res.body).toHaveLength(24);
  expect(res.body[0]).toEqual({ hour: 0, granted: 3, denied: 0 });
  expect(res.body[1]).toEqual({ hour: 1, granted: 0, denied: 0 });
  expect(res.body[23]).toEqual({ hour: 23, granted: 0, denied: 1 });
});

it.each(["2026-02-30", "21/11/2026", "0000-01-01", ""])("rejeita data inválida %j", async (date) => {
  for (const path of [summary, hours]) {
    const res = await api.get(path).query({ date }).set("Authorization", bearer());
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  }
  expect(db.$queryRaw).not.toHaveBeenCalled();
});

it("retorna estado agregado baseado em contato e presença, inclusive dados ausentes ou antigos", async () => {
  const ago = (ms: number) => new Date(now.getTime() - ms);
  const rows = [
    { id: "recent", name: "Recente", lastSeenAt: ago(120_000), lastPresenceAt: ago(5000) },
    { id: "old", name: "Antigo", lastSeenAt: ago(120_001), lastPresenceAt: ago(5001) },
    { id: "null", name: "Sem sinal", lastSeenAt: null, lastPresenceAt: null },
    { id: "future", name: "Futuro", lastSeenAt: ago(-1), lastPresenceAt: ago(-1) },
  ];
  db.terminal.findMany.mockResolvedValue(rows);
  const res = await api.get(status).set("Authorization", bearer());
  expect(res.status).toBe(200);
  expect(res.body.data).toEqual(rows.map(({ lastSeenAt, lastPresenceAt, ...t }, i) => ({
    ...t, lastSeenAt: lastSeenAt?.toISOString() ?? null, lastPresenceAt: lastPresenceAt?.toISOString() ?? null,
    online: i === 0, presenceActive: i === 0,
  })));
  expect(db.terminal.findUnique).not.toHaveBeenCalled();
});
