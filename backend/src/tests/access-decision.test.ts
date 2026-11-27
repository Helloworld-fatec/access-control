import { createHash } from "node:crypto";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import express from "express";
import request from "supertest";

// Prisma simulado: os testes conferem a DECISÃO de acesso e o REGISTRO (AccessLog) de cada tentativa.
const prismaMock = vi.hoisted(() => ({
  terminal: { findFirst: vi.fn(), findUnique: vi.fn(), update: vi.fn() },
  nfcTag: { findUnique: vi.fn() },
  user: { findUnique: vi.fn() },
  authorization: { findMany: vi.fn(), updateMany: vi.fn(), findFirst: vi.fn() },
  accessLog: { create: vi.fn() },
}));
vi.mock("../config/prisma.js", () => ({ prisma: prismaMock }));
vi.mock("../services/door-unlock.service.js", () => ({ requestDoorUnlock: vi.fn() }));

import { accessRoutes } from "../routes/access.routes.js";
import { errorHandler } from "../middlewares/error.middleware.js";

const app = express();
app.use(express.json());
app.use("/access", accessRoutes);
app.use(errorHandler);

const TERMINAL = "11111111-1111-4111-8111-111111111111";
const OTHER_TERMINAL = "22222222-2222-4222-8222-222222222222";
const USER = "33333333-3333-4333-8333-333333333333";
const LOCATION = "44444444-4444-4444-8444-444444444444";
const KEY = "chave-do-terminal-com-mais-de-24-caracteres";
const UID = "04A32F1B";

const authorization = (over: Record<string, unknown> = {}) => ({
  id: "auth-1", userId: USER, locationId: LOCATION, status: "ACTIVE",
  startDate: new Date("2026-11-01T00:00:00.000Z"), endDate: new Date("2026-12-31T00:00:00.000Z"),
  startTime: "08:00", endTime: "20:00", maxUses: null, usedCount: 0, createdAt: new Date(), ...over,
});

const nfc = (key: string | null = KEY, body: Record<string, unknown> = { terminalId: TERMINAL, uid: UID }) => {
  const r = request(app).post("/access/nfc");
  if (key) r.set("x-terminal-key", key);
  return r.send(body);
};
const face = (body: Record<string, unknown>) =>
  request(app).post("/access/face").set("x-terminal-key", KEY).send(body);

/** Confere que a tentativa gerou exatamente UM registro, com os campos esperados. */
function expectLog(data: Record<string, unknown>) {
  expect(prismaMock.accessLog.create).toHaveBeenCalledTimes(1);
  expect(prismaMock.accessLog.create.mock.calls[0][0].data).toMatchObject(data);
}

beforeEach(() => {
  vi.clearAllMocks();
  // 19/11/2026 15:00 em São Paulo (18:00 UTC). Só a data é simulada, para o servidor de teste seguir funcionando.
  vi.useFakeTimers({ toFake: ["Date"] });
  vi.setSystemTime(new Date("2026-11-19T18:00:00.000Z"));

  const terminal = { id: TERMINAL, locationId: LOCATION, apiKeyHash: createHash("sha256").update(KEY).digest("hex") };
  prismaMock.terminal.findFirst.mockResolvedValue(terminal);
  prismaMock.terminal.findUnique.mockImplementation(async ({ where }: { where: { id: string } }) => ({ id: where.id, locationId: LOCATION }));
  prismaMock.terminal.update.mockResolvedValue({});
  prismaMock.nfcTag.findUnique.mockResolvedValue({ uid: UID, userId: USER, active: true });
  prismaMock.user.findUnique.mockResolvedValue({ id: USER, name: "Carlos Ferreira", active: true });
  prismaMock.authorization.findMany.mockResolvedValue([authorization()]);
  prismaMock.authorization.updateMany.mockResolvedValue({ count: 1 });
  prismaMock.accessLog.create.mockResolvedValue({ id: "log-1" });
});
afterEach(() => vi.useRealTimers());

describe("credencial do terminal", () => {
  it("sem chave: 401 e nada é registrado nem consultado", async () => {
    const r = await nfc(null);
    expect(r.status).toBe(401);
    expect(r.body.error.code).toBe("TERMINAL_UNAUTHORIZED");
    expect(prismaMock.nfcTag.findUnique).not.toHaveBeenCalled();
    expect(prismaMock.accessLog.create).not.toHaveBeenCalled();
  });

  it("chave curta ou com formato inválido: 401 sem consultar o banco", async () => {
    const r = await nfc("curta");
    expect(r.status).toBe(401);
    expect(prismaMock.terminal.findFirst).not.toHaveBeenCalled();
  });

  it("chave que não pertence a nenhum terminal: 401", async () => {
    prismaMock.terminal.findFirst.mockResolvedValue(null);
    const r = await nfc();
    expect(r.status).toBe(401);
    expect(r.body.error.message).toBe("Credencial do terminal inválida");
    expect(prismaMock.accessLog.create).not.toHaveBeenCalled();
  });

  it("a chave é procurada pelo hash (SHA-256), nunca em texto puro", async () => {
    await nfc();
    const where = prismaMock.terminal.findFirst.mock.calls[0][0].where;
    expect(where.apiKeyHash).toBe(createHash("sha256").update(KEY).digest("hex"));
    expect(JSON.stringify(where)).not.toContain(KEY);
  });

  it("chave válida atualiza o último contato do terminal", async () => {
    await nfc();
    expect(prismaMock.terminal.update).toHaveBeenCalledWith(expect.objectContaining({ where: { id: TERMINAL } }));
  });

  // ACHADO (para o responsável pelo módulo de acesso): o controller ignora o terminal autenticado
  // (req.terminal) e confia no terminalId do corpo, então um terminal com chave válida pode registrar
  // acessos em nome de outro. Este teste descreve o comportamento CORRETO e hoje FALHA de propósito
  // (it.fails passa enquanto o bug existe). Quando corrigirem, troque it.fails por it.
  it.fails("terminal não pode registrar acesso em nome de outro terminal (corpo ≠ chave)", async () => {
    const r = await nfc(KEY, { terminalId: OTHER_TERMINAL, uid: UID });
    expect(r.status).toBe(403);
    expect(prismaMock.accessLog.create).not.toHaveBeenCalled();
  });
});

describe("validação do pedido", () => {
  it.each([
    [{}],
    [{ terminalId: TERMINAL }],
    [{ terminalId: "nao-e-uuid", uid: UID }],
    [{ terminalId: TERMINAL, uid: "XYZ" }],
    [{ terminalId: TERMINAL, uid: "0A" }],
  ])("NFC com corpo inválido %j: 400 sem registro", async (body) => {
    const r = await nfc(KEY, body);
    expect(r.status).toBe(400);
    expect(prismaMock.accessLog.create).not.toHaveBeenCalled();
  });

  it("terminal inexistente: 404", async () => {
    prismaMock.terminal.findUnique.mockResolvedValue(null);
    const r = await nfc();
    expect(r.status).toBe(404);
    expect(r.body.error.code).toBe("TERMINAL_NOT_FOUND");
  });

  it("UID é normalizado (minúsculas, dois-pontos e espaços) antes de procurar a tag", async () => {
    await nfc(KEY, { terminalId: TERMINAL, uid: "04:a3:2f:1b" });
    expect(prismaMock.nfcTag.findUnique).toHaveBeenCalledWith({ where: { uid: "04A32F1B" } });
  });
});

describe("decisão de acesso por NFC: negativas (cada uma gera um registro)", () => {
  it("tag não cadastrada: INVALID_CREDENTIAL, registro sem usuário e com o UID", async () => {
    prismaMock.nfcTag.findUnique.mockResolvedValue(null);
    const r = await nfc();
    expect(r.status).toBe(403);
    expect(r.body).toMatchObject({ result: "DENIED", allowed: false, reason: "INVALID_CREDENTIAL" });
    expectLog({ userId: null, terminalId: TERMINAL, method: "NFC", result: "DENIED", reason: "INVALID_CREDENTIAL", nfcUid: UID });
  });

  it("tag desativada: INVALID_CREDENTIAL, registro guarda o dono da tag", async () => {
    prismaMock.nfcTag.findUnique.mockResolvedValue({ uid: UID, userId: USER, active: false });
    const r = await nfc();
    expect(r.status).toBe(403);
    expect(r.body.reason).toBe("INVALID_CREDENTIAL");
    expectLog({ userId: USER, result: "DENIED", reason: "INVALID_CREDENTIAL" });
  });

  it("usuário do cartão não existe mais: INVALID_CREDENTIAL sem usuário no registro", async () => {
    prismaMock.user.findUnique.mockResolvedValue(null);
    const r = await nfc();
    expect(r.body.reason).toBe("INVALID_CREDENTIAL");
    expectLog({ userId: null, result: "DENIED", reason: "INVALID_CREDENTIAL" });
  });

  it("usuário inativo: USER_INACTIVE", async () => {
    prismaMock.user.findUnique.mockResolvedValue({ id: USER, name: "Carlos", active: false });
    const r = await nfc();
    expect(r.status).toBe(403);
    expect(r.body.reason).toBe("USER_INACTIVE");
    expectLog({ userId: USER, result: "DENIED", reason: "USER_INACTIVE" });
    expect(prismaMock.authorization.updateMany).not.toHaveBeenCalled();
  });

  it("sem autorização para o local: NO_AUTHORIZATION (e a busca é feita só neste local)", async () => {
    prismaMock.authorization.findMany.mockResolvedValue([]);
    const r = await nfc();
    expect(r.body.reason).toBe("NO_AUTHORIZATION");
    expect(prismaMock.authorization.findMany.mock.calls[0][0].where).toEqual({ userId: USER, locationId: LOCATION });
    expectLog({ result: "DENIED", reason: "NO_AUTHORIZATION" });
  });

  it("autorização cancelada: AUTHORIZATION_CANCELED, registro aponta a autorização", async () => {
    prismaMock.authorization.findMany.mockResolvedValue([authorization({ status: "CANCELED" })]);
    const r = await nfc();
    expect(r.body.reason).toBe("AUTHORIZATION_CANCELED");
    expectLog({ authorizationId: "auth-1", result: "DENIED", reason: "AUTHORIZATION_CANCELED" });
  });

  it.each([
    ["já terminou", { endDate: new Date("2026-11-18T00:00:00.000Z") }],
    ["ainda não começou", { startDate: new Date("2026-11-20T00:00:00.000Z") }],
  ])("fora do período (%s): OUTSIDE_PERIOD", async (_nome, over) => {
    prismaMock.authorization.findMany.mockResolvedValue([authorization(over)]);
    const r = await nfc();
    expect(r.body.reason).toBe("OUTSIDE_PERIOD");
    expectLog({ result: "DENIED", reason: "OUTSIDE_PERIOD" });
  });

  it("último dia do período ainda vale (limite inclusivo)", async () => {
    prismaMock.authorization.findMany.mockResolvedValue([authorization({ endDate: new Date("2026-11-19T00:00:00.000Z") })]);
    expect((await nfc()).status).toBe(200);
  });

  it.each([
    ["antes do horário inicial", { startTime: "16:00", endTime: "20:00" }],
    ["depois do horário final", { startTime: "08:00", endTime: "14:59" }],
  ])("fora do horário (%s, agora são 15:00 em São Paulo): OUTSIDE_SCHEDULE", async (_nome, over) => {
    prismaMock.authorization.findMany.mockResolvedValue([authorization(over)]);
    const r = await nfc();
    expect(r.body.reason).toBe("OUTSIDE_SCHEDULE");
    expectLog({ result: "DENIED", reason: "OUTSIDE_SCHEDULE" });
  });

  it("horário usa São Paulo, não UTC: 15:00 em SP vale numa janela de 14:00 a 16:00 (18:00 UTC não valeria)", async () => {
    prismaMock.authorization.findMany.mockResolvedValue([authorization({ startTime: "14:00", endTime: "16:00" })]);
    expect((await nfc()).status).toBe(200);
  });

  it("usos esgotados (usedCount ≥ maxUses): USES_EXHAUSTED, sem incrementar", async () => {
    prismaMock.authorization.findMany.mockResolvedValue([authorization({ maxUses: 3, usedCount: 3 })]);
    const r = await nfc();
    expect(r.body.reason).toBe("USES_EXHAUSTED");
    expect(prismaMock.authorization.updateMany).not.toHaveBeenCalled();
    expectLog({ result: "DENIED", reason: "USES_EXHAUSTED" });
  });

  it("corrida: outro acesso consumiu o último uso entre a leitura e o incremento: USES_EXHAUSTED", async () => {
    prismaMock.authorization.findMany.mockResolvedValue([authorization({ maxUses: 3, usedCount: 2 })]);
    prismaMock.authorization.updateMany.mockResolvedValue({ count: 0 });
    const r = await nfc();
    expect(r.status).toBe(403);
    expect(r.body.reason).toBe("USES_EXHAUSTED");
    expectLog({ result: "DENIED", reason: "USES_EXHAUSTED" });
  });

  it("mensagem de negação é amigável e não vaza detalhes internos", async () => {
    prismaMock.authorization.findMany.mockResolvedValue([]);
    const r = await nfc();
    expect(r.body.message).toBe("Sem autorização ativa para este local.");
    expect(JSON.stringify(r.body)).not.toMatch(/prisma|stack|SELECT/i);
  });
});

describe("decisão de acesso por NFC: liberação", () => {
  it("libera, devolve o nome e registra GRANTED com a autorização usada", async () => {
    const r = await nfc();
    expect(r.status).toBe(200);
    expect(r.body).toMatchObject({ result: "GRANTED", allowed: true, userName: "Carlos Ferreira", message: "Acesso liberado" });
    expectLog({ userId: USER, terminalId: TERMINAL, authorizationId: "auth-1", method: "NFC", result: "GRANTED", reason: null, nfcUid: UID });
  });

  it("incrementa o contador de usos de forma atômica, só se a autorização seguir ativa", async () => {
    await nfc();
    expect(prismaMock.authorization.updateMany).toHaveBeenCalledWith({
      where: { id: "auth-1", status: "ACTIVE" },
      data: { usedCount: { increment: 1 } },
    });
  });

  it("com limite de usos, o incremento só vale se ainda houver uso disponível", async () => {
    prismaMock.authorization.findMany.mockResolvedValue([authorization({ maxUses: 5, usedCount: 4 })]);
    expect((await nfc()).status).toBe(200);
    expect(prismaMock.authorization.updateMany.mock.calls[0][0].where).toEqual({ id: "auth-1", status: "ACTIVE", usedCount: { lt: 5 } });
  });

  it("usa a primeira autorização válida quando há várias (cancelada e vencida não atrapalham)", async () => {
    prismaMock.authorization.findMany.mockResolvedValue([
      authorization({ id: "cancelada", status: "CANCELED" }),
      authorization({ id: "vencida", endDate: new Date("2026-01-01T00:00:00.000Z") }),
      authorization({ id: "valida" }),
    ]);
    const r = await nfc();
    expect(r.status).toBe(200);
    expectLog({ authorizationId: "valida", result: "GRANTED" });
    expect(prismaMock.authorization.updateMany.mock.calls[0][0].where.id).toBe("valida");
  });

  it("toda tentativa, liberada ou negada, gera exatamente um registro", async () => {
    await nfc();
    prismaMock.authorization.findMany.mockResolvedValue([]);
    await nfc();
    expect(prismaMock.accessLog.create).toHaveBeenCalledTimes(2);
  });
});

describe("decisão de acesso por reconhecimento facial", () => {
  const body = { terminalId: TERMINAL, userId: USER, confidence: 0.93 };

  it("libera e registra o método FACE com a confiança", async () => {
    const r = await face(body);
    expect(r.status).toBe(200);
    expect(r.body.userName).toBe("Carlos Ferreira");
    expectLog({ userId: USER, method: "FACE", result: "GRANTED", confidence: 0.93, nfcUid: null });
  });

  it("nega usuário inativo e registra a negativa", async () => {
    prismaMock.user.findUnique.mockResolvedValue({ id: USER, name: "Carlos", active: false });
    const r = await face(body);
    expect(r.status).toBe(403);
    expectLog({ method: "FACE", result: "DENIED", reason: "USER_INACTIVE" });
  });

  it("usuário desconhecido: INVALID_CREDENTIAL", async () => {
    prismaMock.user.findUnique.mockResolvedValue(null);
    const r = await face(body);
    expect(r.body.reason).toBe("INVALID_CREDENTIAL");
    expectLog({ userId: null, method: "FACE", reason: "INVALID_CREDENTIAL" });
  });

  it.each([
    [{ ...body, confidence: -0.1 }],
    [{ ...body, confidence: 1.1 }],
    [{ ...body, confidence: "alta" }],
    [{ ...body, userId: "nao-e-uuid" }],
    [{ ...body, userId: "demo-face-user" }],
    [{ ...body, userId: "simulated-user" }],
    [{ terminalId: TERMINAL, confidence: 0.9 }],
  ])("corpo inválido %j: 400 e sem registro", async (b) => {
    const r = await face(b);
    expect(r.status).toBe(400);
    expect(prismaMock.accessLog.create).not.toHaveBeenCalled();
  });

  it("exige a credencial do terminal", async () => {
    const r = await request(app).post("/access/face").send(body);
    expect(r.status).toBe(401);
    expect(prismaMock.accessLog.create).not.toHaveBeenCalled();
  });
});
