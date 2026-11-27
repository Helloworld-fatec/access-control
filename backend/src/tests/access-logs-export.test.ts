import { beforeEach, describe, expect, it, vi } from "vitest";
import express from "express";
import jwt from "jsonwebtoken";
import request from "supertest";

const prismaMock = vi.hoisted(() => ({
  accessLog: { count: vi.fn(), findMany: vi.fn() },
  $transaction: vi.fn(),
}));
vi.mock("../config/prisma.js", () => ({ prisma: prismaMock }));

import { accessLogRoutes } from "../routes/access-log.routes.js";
import { errorHandler } from "../middlewares/error.middleware.js";
import { EXPORT_MAX_ROWS } from "../controllers/access-logs.controller.js";

const app = express();
app.use("/access-logs", accessLogRoutes);
app.use(errorHandler);

const secret = process.env.JWT_SECRET as string;
const auth = (role: string) => ({ Authorization: `Bearer ${jwt.sign({ role }, secret, { subject: "u1", expiresIn: "1h" })}` });

const row = (over: Record<string, unknown> = {}) => ({
  id: "l1",
  createdAt: new Date("2026-11-19T21:13:56.000Z"),
  method: "QR",
  result: "GRANTED",
  reason: null,
  nfcUid: null,
  user: { name: "Carlos Ferreira" },
  terminal: { name: "Portaria" },
  ...over,
});

beforeEach(() => {
  vi.clearAllMocks();
  prismaMock.accessLog.count.mockResolvedValue(2);
  prismaMock.accessLog.findMany.mockResolvedValue([row(), row({ id: "l2", result: "DENIED", reason: "OUTSIDE_SCHEDULE", method: "NFC", user: null, nfcUid: "04A32F1B" })]);
});

describe("GET /access-logs/export", () => {
  it("exige autenticação", async () => {
    expect((await request(app).get("/access-logs/export")).status).toBe(401);
  });

  it("recusa quem não é administrador", async () => {
    const r = await request(app).get("/access-logs/export").set(auth("RESIDENT"));
    expect(r.status).toBe(403);
    expect(prismaMock.accessLog.findMany).not.toHaveBeenCalled();
  });

  it("devolve CSV com BOM, cabeçalho em português e linhas traduzidas", async () => {
    const r = await request(app).get("/access-logs/export").set(auth("ADMIN")).buffer(true).parse((res, cb) => {
      let d = "";
      res.setEncoding("utf8");
      res.on("data", (c) => (d += c));
      res.on("end", () => cb(null, d));
    });
    expect(r.status).toBe(200);
    expect(r.headers["content-type"]).toContain("text/csv");
    expect(r.headers["content-disposition"]).toMatch(/attachment; filename="historico-acessos-\d{4}-\d{2}-\d{2}\.csv"/);
    expect(r.headers["cache-control"]).toBe("no-store");
    const text = r.body as string;
    expect(text.startsWith("﻿")).toBe(true);
    const lines = text.replace("﻿", "").split("\r\n").filter(Boolean);
    expect(lines[0]).toBe("Data e hora;Pessoa;Terminal;Método;Resultado;Motivo");
    expect(lines[1]).toBe("19/11/2026 18:13:56;Carlos Ferreira;Portaria;QR Code;Liberado;");
    expect(lines[2]).toBe("19/11/2026 18:13:56;Tag desconhecida;Portaria;Tag NFC;Negado;Fora do horário");
    expect(text).not.toContain("04A32F1B"); // o UID da tag não sai no arquivo
  });

  it("aplica os mesmos filtros da listagem (período em -03:00)", async () => {
    await request(app).get("/access-logs/export?from=2026-11-01&to=2026-11-02&result=DENIED").set(auth("ADMIN"));
    const where = prismaMock.accessLog.findMany.mock.calls[0][0].where;
    expect(where.result).toBe("DENIED");
    expect(where.createdAt.gte.toISOString()).toBe("2026-11-01T03:00:00.000Z");
    expect(where.createdAt.lte.toISOString()).toBe("2026-11-03T02:59:59.999Z");
  });

  it("rejeita filtros inválidos com 400", async () => {
    const r = await request(app).get("/access-logs/export?from=2026-11-05&to=2026-11-01").set(auth("ADMIN"));
    expect(r.status).toBe(400);
  });

  it("lê em lotes usando cursor até acabar", async () => {
    const full = Array.from({ length: 1000 }, (_, i) => row({ id: `a${i}` }));
    prismaMock.accessLog.count.mockResolvedValue(1001);
    prismaMock.accessLog.findMany.mockResolvedValueOnce(full).mockResolvedValueOnce([row({ id: "z" })]);
    const r = await request(app).get("/access-logs/export").set(auth("ADMIN"));
    expect(r.status).toBe(200);
    expect(prismaMock.accessLog.findMany).toHaveBeenCalledTimes(2);
    expect(prismaMock.accessLog.findMany.mock.calls[1][0]).toMatchObject({ cursor: { id: "a999" }, skip: 1 });
  });

  it("devolve 413 quando passa do limite, sem começar o arquivo", async () => {
    prismaMock.accessLog.count.mockResolvedValue(EXPORT_MAX_ROWS + 1);
    const r = await request(app).get("/access-logs/export").set(auth("ADMIN"));
    expect(r.status).toBe(413);
    expect(r.body.error.code).toBe("EXPORT_TOO_LARGE");
    expect(prismaMock.accessLog.findMany).not.toHaveBeenCalled();
  });

  it("neutraliza fórmulas em nomes de pessoas", async () => {
    prismaMock.accessLog.findMany.mockResolvedValue([row({ user: { name: "=HYPERLINK(\"http://x\")" } })]);
    const r = await request(app).get("/access-logs/export").set(auth("ADMIN"));
    expect(r.text).toContain("\"'=HYPERLINK(");
  });
});
