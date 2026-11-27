import { randomUUID } from "node:crypto";
import { EventEmitter } from "node:events";
import request from "supertest";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { hashTerminalKey } from "../config/terminal-key.js";
import { app } from "../index.js";
import { requestDoorUnlock } from "../services/door-unlock.service.js";
import { startMqtt, stopMqtt } from "../services/mqtt.service.js";

const placaId = vi.hoisted(() => "bd33d8b8-419a-4f59-b8f0-5b0da2af669c");
const connectMqtt = vi.hoisted(() => vi.fn());
vi.mock("mqtt", () => ({ connect: connectMqtt }));
vi.mock("node:fs", async (importOriginal) => ({
  ...await importOriginal<typeof import("node:fs")>(),
  readFileSync: vi.fn(() => Buffer.from("CA de teste")),
}));
vi.mock("../config/env.js", async (importOriginal) => {
  const { env } = await importOriginal<typeof import("../config/env.js")>();
  return { env: {
    ...env, ESP32_TERMINAL_ID: placaId, MQTT_URL: "mqtts://test",
    MQTT_CA_FILE: "test-ca.crt", MQTT_BACKEND_PASSWORD: "test-password",
  } };
});
vi.mock("../services/door-unlock.service.js", async (importOriginal) => ({
  ...await importOriginal<typeof import("../services/door-unlock.service.js")>(),
  requestDoorUnlock: vi.fn(),
}));

const db = vi.hoisted(() => ({
  terminal: { findUnique: vi.fn(), findFirst: vi.fn(), update: vi.fn() },
  facetemplate: { findMany: vi.fn() },
  user: { findUnique: vi.fn() },
  authorization: { findMany: vi.fn(), updateMany: vi.fn() },
  accesslog: { findUnique: vi.fn(), findFirst: vi.fn(), create: vi.fn(), update: vi.fn() },
  visit: { createMany: vi.fn() },
  mqttDoorCommand: { createMany: vi.fn(), findMany: vi.fn(), updateMany: vi.fn() },
  $transaction: vi.fn(),
}));
vi.mock("../config/prisma.js", () => ({ prisma: db }));

const path = "/api/access/face/capture";
const terminalId = "face-terminal";
const locationId = "face-location";
const userId = "enrolled-user";
const key = "ab12ef";
const photo = Buffer.from([0xff, 0xd8, 0xff, 0xd9]);
const template = { userId, embedding: Array.from({ length: 1764 }, () => 0.25) };
const match = { result: "MATCH", userId, score: 0.75 };
const python = vi.fn<typeof fetch>();
let nextTestStart = Date.parse("2026-11-21T15:00:00Z");
const upload = (attemptId: string = randomUUID(), credential = key) => request(app)
  .post(path)
  .set("x-terminal-key", credential)
  .set("x-face-attempt-id", attemptId)
  .attach("photos", photo, { filename: "photo.jpg", contentType: "image/jpeg" });
const addPhoto = (uploadRequest: ReturnType<typeof upload>) =>
  uploadRequest.attach("photos", photo, { filename: "photo.jpg", contentType: "image/jpeg" });

beforeEach(() => {
  vi.resetAllMocks();
  vi.stubGlobal("fetch", python);
  // Cada caso exerce o limitador real em sua própria janela.
  vi.setSystemTime(nextTestStart);
  nextTestStart += 120_000;
  db.terminal.findUnique.mockImplementation(({ where }) =>
    where.apiKeyHash === hashTerminalKey(key) ? { id: terminalId, locationId } : null,
  );
  db.facetemplate.findMany.mockResolvedValue([template]);
  db.user.findUnique.mockResolvedValue({ id: userId, name: "Pessoa cadastrada", active: true });
  db.authorization.findMany.mockResolvedValue([{
    id: "face-auth",
    status: "ACTIVE",
    startDate: new Date("2026-11-21"),
    endDate: new Date("2026-11-21"),
    startTime: "08:00",
    endTime: "18:00",
    usedCount: 0,
    maxUses: 2,
  }]);
  db.authorization.updateMany.mockResolvedValue({ count: 1 });
  db.$transaction.mockImplementation((run) => run(db));
  db.accesslog.create.mockImplementation(async ({ data }) => ({ ...data, createdAt: new Date() }));
  python.mockResolvedValue(Response.json(match));
});

afterEach(async () => {
  await stopMqtt();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
  vi.useRealTimers();
});

describe("captura facial do terminal", () => {
  it("envia o lote uma vez e registra e consome uma autorizacao do local autenticado", async () => {
    const attemptId = randomUUID();
    const response = await addPhoto(addPhoto(upload(attemptId)));

    expect(response.status).toBe(200);
    expect(response.body).toMatchObject({ result: "GRANTED", allowed: true });
    expect(db.facetemplate.findMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { modelVersion: "hog-v1", user: { authorizations: { some: { locationId } } } },
    }));
    expect(python).toHaveBeenCalledTimes(1);
    const [url, options] = python.mock.calls[0]!;
    expect((url as URL).pathname).toBe("/match");
    expect(options?.signal).toBeInstanceOf(AbortSignal);
    expect(JSON.parse(options!.body as string)).toEqual({
      photos: Array<string>(3).fill(photo.toString("base64")),
      candidates: [{ ...template, modelVersion: "hog-v1" }],
      minimumScore: 0.75,
      minimumMargin: 0.08,
    });
    expect(db.$transaction).toHaveBeenCalledTimes(1);
    expect(db.authorization.findMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { userId, locationId },
    }));
    expect(db.authorization.updateMany).toHaveBeenCalledTimes(1);
    expect(db.accesslog.create).toHaveBeenCalledExactlyOnceWith({
      data: expect.objectContaining({
        faceAttemptId: attemptId,
        terminalId,
        userId,
        result: "GRANTED",
        confidence: 0.75,
      }),
    });
    const [logged] = db.accesslog.create.mock.calls[0]!;
    expect(db.visit.createMany).toHaveBeenCalledExactlyOnceWith({
      data: { userId, locationId, entryTerminalId: terminalId,
        entryLogId: logged.data.id, enteredAt: new Date() },
      skipDuplicates: true,
    });
    expect(requestDoorUnlock).toHaveBeenCalledExactlyOnceWith({
      accessLogId: logged.data.id, terminalId, userId, method: "FACE",
    });
  });

  it("recusa um rosto reconhecido quando falta autorizacao", async () => {
    db.authorization.findMany.mockResolvedValue([]);
    const response = await upload();

    expect(response.status).toBe(403);
    expect(response.body).toMatchObject({ allowed: false, reason: "NO_AUTHORIZATION" });
    expect(db.authorization.updateMany).not.toHaveBeenCalled();
    expect(db.visit.createMany).not.toHaveBeenCalled();
    expect(requestDoorUnlock).not.toHaveBeenCalled();
    expect(db.accesslog.create).toHaveBeenCalledExactlyOnceWith({
      data: expect.objectContaining({ userId, terminalId, result: "DENIED" }),
    });
  });

  it.each([true, false])("encaminha a concessão facial com a placa inicialmente online=%s", async (online) => {
    vi.useFakeTimers({ toFake: ["Date", "setInterval", "clearInterval"] });
    const emitido = new Date();
    const commandId = randomUUID();
    let placaOnline = online;
    const recebeuOrdem = vi.fn();
    const client = Object.assign(new EventEmitter(), {
      connected: true,
      subscribe: vi.fn((topics: string[], _options, callback) =>
        callback(null, topics.map(() => ({ qos: 1 })))),
      publishAsync: vi.fn((topic: string, message: string, _options: { qos: number; retain: boolean }) => {
        if (placaOnline) recebeuOrdem(topic, message);
      }),
      endAsync: vi.fn(),
    });
    connectMqtt.mockReturnValue(client);
    const atual = await vi.importActual<typeof import("../services/door-unlock.service.js")>(
      "../services/door-unlock.service.js",
    );
    vi.mocked(requestDoorUnlock).mockImplementation(atual.requestDoorUnlock);
    db.accesslog.findFirst.mockImplementation(({ where }) => {
      const registro = db.accesslog.create.mock.calls[0]?.[0].data;
      if (!registro || where.id !== registro.id || where.terminalId !== registro.terminalId ||
          where.userId !== registro.userId || where.method !== registro.method || where.result !== registro.result) return null;
      return { createdAt: emitido, terminal: { locationId } };
    });
    db.terminal.findFirst.mockImplementation(({ where }) =>
      where.id === placaId && where.locationId === locationId ? { id: placaId } : null,
    );
    db.mqttDoorCommand.findMany.mockImplementation(() => {
      const ordem = db.mqttDoorCommand.createMany.mock.calls[0]?.[0].data;
      return ordem ? [{ ...ordem, id: commandId, accessLog: { method: "FACE" } }] : [];
    });
    db.mqttDoorCommand.updateMany.mockResolvedValueOnce({ count: 1 }).mockResolvedValue({ count: 0 });

    startMqtt();
    client.emit("connect");
    expect((await upload()).status).toBe(200);
    const acesso = db.accesslog.create.mock.calls[0]![0].data;
    const expira = new Date(emitido.getTime() + 5000);
    expect(db.mqttDoorCommand.createMany).toHaveBeenCalledExactlyOnceWith({
      data: { terminalId: placaId, accessLogId: acesso.id, issuedAt: emitido, expiresAt: expira },
      skipDuplicates: true,
    });
    expect(acesso).toMatchObject({ terminalId, method: "FACE", result: "GRANTED" });

    if (!online) {
      await vi.advanceTimersByTimeAsync(5500);
      expect(client.publishAsync).toHaveBeenCalled();
      expect(recebeuOrdem).not.toHaveBeenCalled();
      client.publishAsync.mockClear();
      placaOnline = true;
      await vi.advanceTimersByTimeAsync(500);
      expect(client.publishAsync).not.toHaveBeenCalled();
      expect(recebeuOrdem).not.toHaveBeenCalled();
      expect(db.accesslog.update).not.toHaveBeenCalled();
      return;
    }

    await vi.advanceTimersByTimeAsync(500);
    expect(recebeuOrdem).toHaveBeenCalledTimes(1);
    const [topico, mensagem, opcoes] = client.publishAsync.mock.calls[0]!;
    const ordem = JSON.parse(mensagem);
    expect(topico).toBe(`access/v1/terminals/${placaId}/door/command`);
    expect(ordem).toMatchObject({
      terminalId: placaId, method: "FACE", requestId: acesso.id, accessLogId: acesso.id,
      unlockDurationMs: 3000, expiresAt: expira.toISOString(),
    });
    expect(opcoes).toMatchObject({ qos: 1, retain: false });
    const acceptedAt = new Date().toISOString();
    await vi.advanceTimersByTimeAsync(5120);
    const ack = Buffer.from(JSON.stringify({
      schemaVersion: 1, terminalId: placaId, eventId: randomUUID(),
      requestId: ordem.requestId, accessLogId: ordem.accessLogId,
      result: "UNLOCKED", acceptedAt, occurredAt: new Date().toISOString(),
    }));
    client.emit("message", `access/v1/terminals/${placaId}/door/ack`, ack, { retain: false });
    await vi.advanceTimersByTimeAsync(0);
    expect(db.mqttDoorCommand.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({
        terminalId: placaId, accessLogId: acesso.id, expiresAt: { gt: new Date(acceptedAt) },
      }),
    }));
    expect(db.accesslog.update).toHaveBeenCalledExactlyOnceWith({
      where: { id: acesso.id }, data: { commandAcked: true },
    });
  });

  it.each(["UNKNOWN_FACE", "AMBIGUOUS_FACE"])("registra %s sem vincular usuario", async (result) => {
    python.mockResolvedValue(Response.json({ result }));
    const response = await upload();

    expect(response.status).toBe(403);
    expect(response.body).toMatchObject({ allowed: false, reason: result });
    expect(db.authorization.updateMany).not.toHaveBeenCalled();
    expect(requestDoorUnlock).not.toHaveBeenCalled();
    expect(db.accesslog.create).toHaveBeenCalledExactlyOnceWith({
      data: expect.objectContaining({ terminalId, result: "DENIED", reason: result }),
    });
  });

  it.each([
    [422, "NO_FACE"],
    [422, "MULTIPLE_FACES"],
    [422, "CORRUPT_IMAGE"],
    [413, "IMAGE_DIMENSIONS_TOO_LARGE"],
  ])("registra falha de captura %s %s", async (status, code) => {
    python.mockResolvedValue(Response.json({ detail: { code } }, { status }));
    const response = await upload();

    expect(response.status).toBe(status);
    expect(response.body.error.code).toBe(code);
    expect(db.accesslog.create).toHaveBeenCalledTimes(1);
    expect(db.authorization.updateMany).not.toHaveBeenCalled();
  });

  it("recusa resposta do Python com identidade fora dos candidatos", async () => {
    python.mockResolvedValue(Response.json({ ...match, userId: "another-location" }));
    const response = await upload();

    expect(response.status).toBe(502);
    expect(response.body.error.code).toBe("FACE_SERVICE_INVALID_RESPONSE");
    expect(db.user.findUnique).not.toHaveBeenCalled();
  });

  it("recusa score abaixo do limiar mesmo quando o Python declara MATCH", async () => {
    python.mockResolvedValue(Response.json({ ...match, score: 0.50 }));
    const response = await upload();

    expect(response.status).toBe(502);
    expect(response.body.error.code).toBe("FACE_SERVICE_INVALID_RESPONSE");
    expect(db.authorization.updateMany).not.toHaveBeenCalled();
  });

  it("recusa templates incompat?veis sem chamar o Python", async () => {
    db.facetemplate.findMany.mockResolvedValue([{ userId, embedding: [0.25] }]);
    const response = await upload();

    expect(response.status).toBe(422);
    expect(response.body.error.code).toBe("FACE_NO_COMPATIBLE_TEMPLATES");
    expect(python).not.toHaveBeenCalled();
    expect(db.accesslog.create).toHaveBeenCalledTimes(1);
  });

  it("registra a indisponibilidade do Python sem conceder acesso", async () => {
    python.mockRejectedValue(new Error("connection refused"));
    const response = await upload();

    expect(response.status).toBe(502);
    expect(response.body.error.code).toBe("FACE_SERVICE_UNAVAILABLE");
    expect(db.authorization.updateMany).not.toHaveBeenCalled();
    expect(db.accesslog.create).toHaveBeenCalledTimes(1);
  });

  it("registra o timeout do Python", async () => {
    vi.spyOn(AbortSignal, "timeout").mockReturnValue(AbortSignal.abort());
    python.mockRejectedValue(new Error("request timed out"));
    const response = await upload();

    expect(response.status).toBe(504);
    expect(response.body.error.code).toBe("FACE_SERVICE_TIMEOUT");
    expect(db.authorization.updateMany).not.toHaveBeenCalled();
    expect(db.accesslog.create).toHaveBeenCalledTimes(1);
  });

  it("recusa repetir um UUID para o mesmo terminal", async () => {
    const attemptId = randomUUID();
    expect((await upload(attemptId)).status).toBe(200);
    db.accesslog.findUnique.mockResolvedValue({ id: "created-log" });

    const replay = await upload(attemptId);
    expect(replay.status).toBe(409);
    expect(replay.body.error.code).toBe("FACE_ATTEMPT_REPLAYED");
    expect(db.accesslog.findUnique).toHaveBeenLastCalledWith({
      where: { terminalId_faceAttemptId: { terminalId, faceAttemptId: attemptId } },
      select: { id: true },
    });
    expect(python).toHaveBeenCalledTimes(1);
    expect(db.authorization.updateMany).toHaveBeenCalledTimes(1);
    expect(db.accesslog.create).toHaveBeenCalledTimes(1);
  });

  it("trata o conflito de indice quando outra requisicao conclui a mesma tentativa", async () => {
    db.$transaction.mockRejectedValue({ code: "P2002" });
    db.accesslog.findUnique.mockResolvedValueOnce(null).mockResolvedValueOnce({ id: "winning-log" });

    const response = await upload();
    expect(response.status).toBe(409);
    expect(response.body.error.code).toBe("FACE_ATTEMPT_REPLAYED");
  });

  it("exige chave, UUID, no maximo tres imagens e nenhum campo de identidade", async () => {
    expect((await upload(randomUUID(), "ffffff")).status).toBe(401);
    expect((await upload("invalid-attempt")).status).toBe(400);
    expect((await addPhoto(addPhoto(addPhoto(upload())))).status).toBe(400);
    expect((await upload().field("terminalId", "different-terminal")).status).toBe(400);
    const oversized = await request(app).post(path)
      .set("x-terminal-key", key)
      .set("x-face-attempt-id", randomUUID())
      .attach("photos", Buffer.alloc(102_401), { filename: "large.jpg", contentType: "image/jpeg" });
    expect(oversized.status).toBe(413);
    expect(python).not.toHaveBeenCalled();
    expect(db.accesslog.create).not.toHaveBeenCalled();
  });
});
