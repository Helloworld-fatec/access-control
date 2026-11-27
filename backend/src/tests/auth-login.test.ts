import { beforeEach, describe, expect, it, vi } from "vitest";
import express from "express";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import request from "supertest";

const prismaMock = vi.hoisted(() => ({ user: { findUnique: vi.fn() } }));
vi.mock("../config/prisma.js", () => ({ prisma: prismaMock }));

import { authRoutes } from "../routes/auth.routes.js";
import { errorHandler } from "../middlewares/error.middleware.js";

const app = express();
app.use(express.json());
app.use("/login", authRoutes);
app.use(errorHandler);

const PASSWORD = "Senha1234";
// Custo 4 só nos testes, para não demorar; em produção vale BCRYPT_ROUNDS.
const passwordHash = bcrypt.hashSync(PASSWORD, 4);
const dbUser = (over: Record<string, unknown> = {}) => ({
  id: "u1", name: "Admin", email: "admin@teste.com", role: "ADMIN", active: true,
  passwordHash, document: null, phone: null, createdAt: new Date(), updatedAt: new Date(), ...over,
});

beforeEach(() => vi.clearAllMocks());

describe("POST /login: credenciais", () => {
  it("credenciais válidas devolvem token JWT assinado, do usuário e com o perfil", async () => {
    prismaMock.user.findUnique.mockResolvedValue(dbUser());
    const r = await request(app).post("/login").send({ email: "admin@teste.com", password: PASSWORD });
    expect(r.status).toBe(200);
    expect(r.body.tokenType).toBe("Bearer");
    const payload = jwt.verify(r.body.accessToken, process.env.JWT_SECRET as string) as jwt.JwtPayload;
    expect(payload.sub).toBe("u1");
    expect(payload.role).toBe("ADMIN");
    expect(payload.exp).toBeGreaterThan(payload.iat as number);
  });

  it("nunca devolve o hash da senha na resposta", async () => {
    prismaMock.user.findUnique.mockResolvedValue(dbUser());
    const r = await request(app).post("/login").send({ email: "admin@teste.com", password: PASSWORD });
    expect(JSON.stringify(r.body)).not.toContain(passwordHash);
    expect(r.body.user).not.toHaveProperty("passwordHash");
  });

  it("normaliza o e-mail (espaços e maiúsculas) antes de buscar", async () => {
    prismaMock.user.findUnique.mockResolvedValue(dbUser());
    await request(app).post("/login").send({ email: "  ADMIN@Teste.com ", password: PASSWORD });
    expect(prismaMock.user.findUnique).toHaveBeenCalledWith({ where: { email: "admin@teste.com" } });
  });

  it("senha errada, e-mail desconhecido e usuário inativo dão a mesma resposta (sem revelar qual falhou)", async () => {
    const respostas = [];
    prismaMock.user.findUnique.mockResolvedValueOnce(dbUser());
    respostas.push(await request(app).post("/login").send({ email: "admin@teste.com", password: "errada" }));
    prismaMock.user.findUnique.mockResolvedValueOnce(null);
    respostas.push(await request(app).post("/login").send({ email: "naoexiste@teste.com", password: PASSWORD }));
    prismaMock.user.findUnique.mockResolvedValueOnce(dbUser({ active: false }));
    respostas.push(await request(app).post("/login").send({ email: "admin@teste.com", password: PASSWORD }));
    for (const r of respostas) {
      expect(r.status).toBe(401);
      expect(r.body.error.code).toBe("INVALID_CREDENTIALS");
      expect(r.body).toEqual(respostas[0].body);
      expect(r.body.accessToken).toBeUndefined();
    }
  });

  it.each([
    [{}],
    [{ email: "admin@teste.com" }],
    [{ password: PASSWORD }],
    [{ email: "nao-e-email", password: PASSWORD }],
    [{ email: "admin@teste.com", password: "" }],
    [{ email: "admin@teste.com", password: "x".repeat(73) }],
  ])("rejeita corpo inválido %j com 400, sem consultar o banco", async (body) => {
    const r = await request(app).post("/login").send(body);
    expect(r.status).toBe(400);
    expect(r.body.error.code).toBe("VALIDATION_ERROR");
    expect(prismaMock.user.findUnique).not.toHaveBeenCalled();
  });
});
