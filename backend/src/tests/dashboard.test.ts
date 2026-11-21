import { beforeEach, describe, expect, it, vi } from "vitest";
import express from "express";
import jwt from "jsonwebtoken";
import request from "supertest";

// Prisma simulado: os testes conferem a montagem das respostas e a proteção das rotas, sem banco.
const prismaMock = vi.hoisted(() => ({
  accessLog: { groupBy: vi.fn() },
  authorization: { count: vi.fn() },
  terminal: { findMany: vi.fn() },
  $queryRaw: vi.fn(),
}));
vi.mock("../config/prisma.js", () => ({ prisma: prismaMock }));

import { dashboardRoutes } from "../routes/dashboard.routes.js";
import { terminalRoutes } from "../routes/terminal.routes.js";
import { errorHandler } from "../middlewares/error.middleware.js";

const app = express();
app.use(express.json());
app.use("/dashboard", dashboardRoutes);
app.use("/terminals", terminalRoutes);
app.use(errorHandler);

const secret = process.env.JWT_SECRET as string;
const token = (role: string) => jwt.sign({ role }, secret, { subject: "u1", expiresIn: "1h" });
const admin = { Authorization: `Bearer ${token("ADMIN")}` };

beforeEach(() => {
  vi.clearAllMocks();
  prismaMock.accessLog.groupBy.mockImplementation(async ({ by }: { by: string[] }) => {
    if (by[0] === "result") return [{ result: "GRANTED", _count: { _all: 6 } }, { result: "DENIED", _count: { _all: 2 } }];
    if (by[0] === "method") return [{ method: "QR", _count: { _all: 5 } }, { method: "NFC", _count: { _all: 3 } }];
    return [{ reason: "OUTSIDE_SCHEDULE", _count: { _all: 2 } }];
  });
  prismaMock.authorization.count.mockResolvedValueOnce(9).mockResolvedValueOnce(2).mockResolvedValueOnce(1);
});

describe("GET /dashboard/summary", () => {
  it("exige token de administrador", async () => {
    expect((await request(app).get("/dashboard/summary")).status).toBe(401);
    const res = await request(app).get("/dashboard/summary").set({ Authorization: `Bearer ${token("RESIDENT")}` });
    expect(res.status).toBe(403);
  });

  it("calcula liberados, negados, taxa, métodos, autorizações e motivos", async () => {
    const res = await request(app).get("/dashboard/summary?date=2026-11-19").set(admin);
    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      date: "2026-11-19",
      granted: 6,
      denied: 2,
      denialRate: 0.25,
      byMethod: { QR: 5, NFC: 3, FACE: 0 },
      authorizations: { active: 9, expiringSoon: 2, canceled: 1 },
      topDenialReasons: [{ reason: "OUTSIDE_SCHEDULE", count: 2 }],
    });
  });

  it("usa o dia de São Paulo, de 00:00 a 24:00 (-03:00)", async () => {
    await request(app).get("/dashboard/summary?date=2026-11-19").set(admin);
    const where = prismaMock.accessLog.groupBy.mock.calls[0][0].where.createdAt;
    expect(where.gte.toISOString()).toBe("2026-11-19T03:00:00.000Z");
    expect(where.lt.toISOString()).toBe("2026-11-20T03:00:00.000Z");
  });

  it("taxa de negação é 0 quando não há acessos", async () => {
    prismaMock.accessLog.groupBy.mockResolvedValue([]);
    const res = await request(app).get("/dashboard/summary").set(admin);
    expect(res.body).toMatchObject({ granted: 0, denied: 0, denialRate: 0 });
  });

  it("recusa data inválida", async () => {
    const res = await request(app).get("/dashboard/summary?date=2026-02-31").set(admin);
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  });
});

describe("GET /dashboard/accesses-by-hour", () => {
  it("devolve sempre 24 horas, com zeros onde não houve acesso", async () => {
    prismaMock.$queryRaw.mockResolvedValue([
      { hour: 8, result: "GRANTED", total: 4 },
      { hour: 8, result: "DENIED", total: 1 },
      { hour: 18, result: "GRANTED", total: 2 },
    ]);
    const res = await request(app).get("/dashboard/accesses-by-hour?date=2026-11-19").set(admin);
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(24);
    expect(res.body[8]).toEqual({ hour: 8, granted: 4, denied: 1 });
    expect(res.body[18]).toEqual({ hour: 18, granted: 2, denied: 0 });
    expect(res.body[0]).toEqual({ hour: 0, granted: 0, denied: 0 });
  });
});

describe("GET /terminals/status", () => {
  it("exige administrador", async () => {
    expect((await request(app).get("/terminals/status")).status).toBe(401);
  });

  it("considera online quem falou com a API há pouco, mesmo com online=false no banco", async () => {
    const now = Date.now();
    prismaMock.terminal.findMany.mockResolvedValue([
      { id: "a", name: "Portaria", online: false, lastPresenceAt: new Date(now - 1000), lastSeenAt: new Date(now - 10_000) },
      { id: "b", name: "Sala", online: false, lastPresenceAt: null, lastSeenAt: new Date(now - 10 * 60_000) },
    ]);
    const res = await request(app).get("/terminals/status").set(admin);
    expect(res.status).toBe(200);
    expect(res.body.data[0]).toMatchObject({ id: "a", online: true, presenceActive: true });
    expect(res.body.data[1]).toMatchObject({ id: "b", online: false, presenceActive: false });
  });
});
