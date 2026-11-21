import jwt from "jsonwebtoken";
import request from "supertest";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { env } from "../config/env.js";
import { app } from "../index.js";

const db = vi.hoisted(() => ({
  user: { findUnique: vi.fn() },
  location: {
    findMany: vi.fn(), count: vi.fn(), create: vi.fn(),
    findUnique: vi.fn(), update: vi.fn(), delete: vi.fn(),
  },
  accesslog: { findMany: vi.fn(), count: vi.fn() },
  terminal: { count: vi.fn() },
  authorization: { count: vi.fn(), findMany: vi.fn() },
  $transaction: vi.fn(),
}));
vi.mock("../config/prisma.js", () => ({ prisma: db }));

const id = "14825695-6cdb-4e40-a33e-94045475eabb";
const data = { building: "Bloco A" };
const location = { id, ...data, entrance: null, door: null, turnstile: null, description: null };
const path = "/api/locations";
const api = request(app);
const admin = { role: "ADMIN", active: true };
const resident = { role: "RESIDENT", active: true };

const endpoints = [
  ["GET /locations", () => api.get(path), 200],
  ["POST /locations", () => api.post(path).send(data), 201],
  ["GET /locations/:id", () => api.get(`${path}/${id}`), 200],
  ["PUT /locations/:id", () => api.put(`${path}/${id}`).send(data), 200],
  ["DELETE /locations/:id", () => api.delete(`${path}/${id}`), 204],
  ["GET /access-logs", () => api.get("/api/access-logs"), 200],
] as const;

function bearer(role = "ADMIN", expiresIn = 60) {
  return `Bearer ${jwt.sign({ role }, env.JWT_SECRET, { subject: id, expiresIn })}`;
}

function expectNoBusinessOperations() {
  for (const model of [db.location, db.accesslog, db.terminal, db.authorization]) {
    for (const operation of Object.values(model)) expect(operation).not.toHaveBeenCalled();
  }
  expect(db.$transaction).not.toHaveBeenCalled();
}

beforeEach(() => {
  vi.resetAllMocks();
  db.user.findUnique.mockResolvedValue(admin);
  db.$transaction.mockImplementation((queries: Promise<unknown>[]) => Promise.all(queries));
  db.location.findMany.mockResolvedValue([location]);
  db.location.count.mockResolvedValue(1);
  db.location.findUnique.mockResolvedValue(location);
  db.location.create.mockResolvedValue(location);
  db.location.update.mockResolvedValue(location);
  db.terminal.count.mockResolvedValue(0);
  db.authorization.count.mockResolvedValue(0);
  db.authorization.findMany.mockResolvedValue([]);
  db.accesslog.findMany.mockResolvedValue([]);
  db.accesslog.count.mockResolvedValue(0);
});

describe.each(endpoints)("%s exige administrador", (_label, send, successStatus) => {
  it("exige JWT e rejeita chave de terminal", async () => {
    expect((await send()).status).toBe(401);
    const response = await send().set("x-terminal-key", "abc123");
    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe("UNAUTHORIZED");
    expect(db.user.findUnique).not.toHaveBeenCalled();
    expectNoBusinessOperations();
  });

  it.each([
    ["inválido", "Bearer invalid"],
    ["expirado", bearer("ADMIN", -60)],
  ])("rejeita um token %s", async (_description, token) => {
    const response = await send().set("Authorization", token);
    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe("INVALID_TOKEN");
    expect(db.user.findUnique).not.toHaveBeenCalled();
    expectNoBusinessOperations();
  });

  it.each([
    ["comum", "RESIDENT", resident],
    ["desativado", "ADMIN", { ...admin, active: false }],
    ["rebaixado", "ADMIN", resident],
  ])("recusa usuário %s", async (_description, role, currentUser) => {
    db.user.findUnique.mockResolvedValue(currentUser);
    const response = await send().set("Authorization", bearer(role));
    expect(response.status).toBe(403);
    expect(response.body.error.code).toBe("FORBIDDEN");
    expectNoBusinessOperations();
  });

  it("entrega a resposta normal para administrador ativo", async () => {
    const response = await send().set("Authorization", bearer());
    expect(response.status).toBe(successStatus);
    expect(db.user.findUnique).toHaveBeenCalledWith({
      where: { id },
      select: { role: true, active: true },
    });
  });
});

it("preserva a consulta de autorizações próprias para JWT de usuário comum", async () => {
  db.user.findUnique.mockResolvedValue(resident);
  const response = await api.get("/api/authorizations/me").set("Authorization", bearer("RESIDENT"));
  expect(response.status).toBe(200);
  expect(response.body).toMatchObject({ data: [], total: 0 });
  expect(db.authorization.findMany).toHaveBeenCalledWith(
    expect.objectContaining({ where: expect.objectContaining({ userId: id }) }),
  );
  expect(db.user.findUnique).not.toHaveBeenCalled();
});
