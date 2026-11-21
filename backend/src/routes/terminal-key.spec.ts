import jwt from "jsonwebtoken";
import request from "supertest";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { env } from "../config/env.js";
import { generateTerminalKey, hashTerminalKey } from "../config/terminal-key.js";
import { app } from "../index.js";

const db = vi.hoisted(() => ({
  user: { findUnique: vi.fn() },
  location: { findUnique: vi.fn() },
  terminal: { create: vi.fn(), findUnique: vi.fn(), update: vi.fn(), updateMany: vi.fn() },
}));

vi.mock("../config/prisma.js", () => ({ prisma: db }));
vi.mock("../config/terminal-key.js", async (importOriginal) => ({
  ...await importOriginal<typeof import("../config/terminal-key.js")>(),
  generateTerminalKey: vi.fn(),
}));

const id = "14825695-6cdb-4e40-a33e-94045475eabb";
const otherId = "14825695-6cdb-4e40-a33e-94045475eabc";
const dto = { name: "Entrada", locationId: otherId, latitude: 0, longitude: 0 };
const terminal = { id, ...dto, online: true, lastPresenceAt: null };
const path = `/api/terminals/${id}`;
const api = request(app);

function bearer(role = "ADMIN") {
  return `Bearer ${jwt.sign({ role }, env.JWT_SECRET, { subject: id })}`;
}

beforeEach(() => {
  vi.resetAllMocks();
  db.user.findUnique.mockResolvedValue({ role: "ADMIN", active: true });
  db.location.findUnique.mockResolvedValue({ id: otherId });
});

describe("código de terminal", () => {
  it("repete a criação em caso de colisão e devolve apenas o código gravado", async () => {
    vi.mocked(generateTerminalKey).mockReturnValueOnce("aaaaaa").mockReturnValueOnce("01abef");
    db.terminal.create.mockRejectedValueOnce({ code: "P2002" }).mockResolvedValueOnce(terminal);

    const response = await api.post("/api/terminals").set("Authorization", bearer()).send(dto);

    expect(response.status).toBe(201);
    expect(response.body.apiKey).toBe("01abef");
    expect(response.body).not.toHaveProperty("apiKeyHash");
    expect(db.terminal.create).toHaveBeenLastCalledWith(expect.objectContaining({
      data: expect.objectContaining({ apiKeyHash: hashTerminalKey("01abef") }),
    }));
  });

  it.each([
    ["x-terminal-key", "01ABEF"],
    ["x-api-key", "01abef"],
    ["Authorization", "Bearer 01ABEF"],
  ])("autentica o equipamento pelo cabeçalho %s", async (header, value) => {
    db.terminal.findUnique.mockResolvedValue(terminal);

    const response = await api.get(`${path}/status`).set(header, value);

    expect(response.status).toBe(200);
    expect(db.terminal.findUnique).toHaveBeenNthCalledWith(1, expect.objectContaining({
      where: { apiKeyHash: hashTerminalKey("01abef") },
    }));
    expect(db.terminal.update).toHaveBeenCalledWith(expect.objectContaining({
      where: { id },
      data: { lastSeenAt: expect.any(Date) },
    }));
  });

  it("recusa códigos fora do formato e credenciais de outro terminal", async () => {
    expect((await api.get(`${path}/status`).set("x-terminal-key", "abc1234")).status).toBe(401);
    expect(db.terminal.findUnique).not.toHaveBeenCalled();
    db.terminal.findUnique.mockResolvedValue({ ...terminal, id: otherId });
    expect((await api.get(`${path}/status`).set("x-terminal-key", "01abef")).status).toBe(403);
    expect(db.terminal.update).not.toHaveBeenCalled();
  });

  it("identifica o terminal autenticado somente pela chave", async () => {
    db.terminal.findUnique.mockResolvedValue(terminal);

    const response = await api.get("/api/terminals/me").set("x-terminal-key", "01ABEF");

    expect(response.status).toBe(200);
    expect(response.body).toEqual({ id });
    expect(db.user.findUnique).not.toHaveBeenCalled();
    expect(db.terminal.findUnique).toHaveBeenCalledWith(expect.objectContaining({
      where: { apiKeyHash: hashTerminalKey("01abef") },
    }));
  });

  it("recusa identificar o terminal com uma chave desconhecida", async () => {
    db.terminal.findUnique.mockResolvedValue(null);

    const response = await api.get("/api/terminals/me").set("x-terminal-key", "01abef");

    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe("TERMINAL_UNAUTHORIZED");
    expect(db.terminal.update).not.toHaveBeenCalled();
  });

  it("troca a chave de um terminal existente e a anterior perde acesso", async () => {
    vi.mocked(generateTerminalKey).mockReturnValueOnce("01abef").mockReturnValueOnce("abc123");
    db.terminal.updateMany.mockResolvedValueOnce({ count: 0 }).mockResolvedValueOnce({ count: 1 });
    db.terminal.findUnique.mockResolvedValueOnce(terminal).mockResolvedValueOnce(null);

    const response = await api.post(`${path}/rotate-key`).set("Authorization", bearer());

    expect(response.status).toBe(200);
    expect(response.body).toEqual({ apiKey: "abc123" });
    const hash = hashTerminalKey("abc123");
    expect(db.terminal.updateMany).toHaveBeenLastCalledWith({
      where: { id, apiKeyHash: { not: hash } },
      data: { apiKeyHash: hash },
    });
    expect((await api.get(`${path}/status`).set("x-terminal-key", "01abef")).status).toBe(401);
  });

  it("restringe a rotação a administradores", async () => {
    db.user.findUnique.mockResolvedValue({ role: "USER", active: true });
    expect((await api.post(`${path}/rotate-key`).set("Authorization", bearer("USER"))).status).toBe(403);
    expect(db.terminal.updateMany).not.toHaveBeenCalled();
  });

  it("limita tentativas inválidas entre rotas de equipamento", async () => {
    let status = 0;
    for (let attempt = 0; attempt <= 30 && status !== 429; attempt += 1) {
      status = (await api.get(`${path}/status`).set("x-terminal-key", "invalid")).status;
    }
    const response = await api.post("/api/access/nfc").set("x-api-key", "abc123");
    expect(status).toBe(429);
    expect(response.status).toBe(429);
    expect(response.headers["retry-after"]).toBeDefined();
    expect(db.terminal.findUnique).not.toHaveBeenCalled();
  });
});
