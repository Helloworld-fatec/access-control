import { beforeEach, describe, expect, it, vi } from "vitest";
import express from "express";
import request from "supertest";

const prismaMock = vi.hoisted(() => ({
  accessLog: { findMany: vi.fn(), count: vi.fn() },
  $transaction: vi.fn(),
}));
vi.mock("../config/prisma.js", () => ({ prisma: prismaMock }));

import { accessLogRoutes } from "../routes/access-log.routes.js";
import { errorHandler } from "../middlewares/error.middleware.js";

const app = express();
app.use("/access-logs", accessLogRoutes);
app.use(errorHandler);

const TERMINAL = "11111111-1111-4111-8111-111111111111";
const USER = "33333333-3333-4333-8333-333333333333";
const row = (over: Record<string, unknown> = {}) => ({
  id: "l1", userId: USER, terminalId: TERMINAL, authorizationId: "a1", method: "NFC", result: "DENIED",
  reason: "OUTSIDE_SCHEDULE", nfcUid: "04A32F1B", confidence: null, distanceMeters: null, commandAcked: null,
  createdAt: new Date("2026-11-19T18:00:00.000Z"), user: { id: USER, name: "Carlos" }, terminal: { id: TERMINAL, name: "Portaria" }, ...over,
});

beforeEach(() => {
  vi.clearAllMocks();
  prismaMock.accessLog.findMany.mockResolvedValue([row()]);
  prismaMock.accessLog.count.mockResolvedValue(41);
  // $transaction([...]) recebe as consultas já criadas e devolve os resultados na mesma ordem.
  prismaMock.$transaction.mockImplementation((queries: unknown[]) => Promise.all(queries));
});

describe("GET /access-logs: leitura do histórico", () => {
  it("devolve os registros com pessoa, terminal, motivo e paginação", async () => {
    const r = await request(app).get("/access-logs?page=2&pageSize=20");
    expect(r.status).toBe(200);
    expect(r.body.data[0]).toMatchObject({
      id: "l1", method: "NFC", result: "DENIED", reason: "OUTSIDE_SCHEDULE",
      user: { name: "Carlos" }, terminal: { name: "Portaria" },
    });
    expect(r.body).toMatchObject({ page: 2, pageSize: 20, total: 41, totalPages: 3 });
    const args = prismaMock.accessLog.findMany.mock.calls[0][0];
    expect(args.skip).toBe(20);
    expect(args.take).toBe(20);
    expect(args.orderBy).toEqual({ createdAt: "desc" });
  });

  it("registro sem usuário (tag desconhecida) é listado com user nulo", async () => {
    prismaMock.accessLog.findMany.mockResolvedValue([row({ userId: null, user: null, reason: "INVALID_CREDENTIAL" })]);
    const r = await request(app).get("/access-logs");
    expect(r.body.data[0].userId).toBeNull();
    expect(r.body.data[0].user).toBeNull();
  });

  it("aplica todos os filtros no banco: pessoa, terminal, método, resultado e período em São Paulo", async () => {
    await request(app).get(`/access-logs?userId=${USER}&terminalId=${TERMINAL}&method=QR&result=GRANTED&from=2026-11-01&to=2026-11-02`);
    const where = prismaMock.accessLog.findMany.mock.calls[0][0].where;
    expect(where).toMatchObject({ userId: USER, terminalId: TERMINAL, method: "QR", result: "GRANTED" });
    expect(where.createdAt.gte.toISOString()).toBe("2026-11-01T03:00:00.000Z");
    expect(where.createdAt.lte.toISOString()).toBe("2026-11-03T02:59:59.999Z");
    expect(prismaMock.accessLog.count.mock.calls[0][0].where).toEqual(where);
  });

  it("sem filtros, não restringe nada", async () => {
    await request(app).get("/access-logs");
    expect(prismaMock.accessLog.findMany.mock.calls[0][0].where).toEqual({});
  });

  it.each([
    ["método desconhecido", "method=PIN"],
    ["resultado desconhecido", "result=MAYBE"],
    ["pessoa que não é UUID", "userId=123"],
    ["data fora do formato", "from=19/11/2026"],
    ["período invertido", "from=2026-11-05&to=2026-11-01"],
  ])("filtro inválido (%s): 400 sem consultar o banco", async (_nome, qs) => {
    const r = await request(app).get(`/access-logs?${qs}`);
    expect(r.status).toBe(400);
    expect(prismaMock.accessLog.findMany).not.toHaveBeenCalled();
  });

  it("não há rota para gravar ou apagar registros pela API (histórico só de leitura)", async () => {
    expect((await request(app).post("/access-logs").send({})).status).toBe(404);
    expect((await request(app).delete("/access-logs/l1")).status).toBe(404);
    expect((await request(app).put("/access-logs/l1").send({})).status).toBe(404);
  });
});
