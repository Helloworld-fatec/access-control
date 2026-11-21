import { randomUUID } from "node:crypto";
import request from "supertest";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { hashTerminalKey } from "../config/terminal-key.js";
import { app } from "../index.js";

const db = vi.hoisted(() => ({
  terminal: { findUnique: vi.fn(), update: vi.fn() },
  facetemplate: { findMany: vi.fn() },
  user: { findUnique: vi.fn() },
  authorization: { findMany: vi.fn(), updateMany: vi.fn() },
  accesslog: { findUnique: vi.fn(), create: vi.fn() },
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
const match = { result: "MATCH", userId, score: 0.96 };
const python = vi.fn<typeof fetch>();
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
  vi.setSystemTime(new Date("2026-11-21T15:00:00Z"));
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
  python.mockResolvedValue(Response.json(match));
});

afterEach(() => {
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
      minimumScore: 0.93,
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
        confidence: 0.96,
      }),
    });
  });

  it("recusa um rosto reconhecido quando falta autorizacao", async () => {
    db.authorization.findMany.mockResolvedValue([]);
    const response = await upload();

    expect(response.status).toBe(403);
    expect(response.body).toMatchObject({ allowed: false, reason: "NO_AUTHORIZATION" });
    expect(db.authorization.updateMany).not.toHaveBeenCalled();
    expect(db.accesslog.create).toHaveBeenCalledExactlyOnceWith({
      data: expect.objectContaining({ userId, terminalId, result: "DENIED" }),
    });
  });

  it.each(["UNKNOWN_FACE", "AMBIGUOUS_FACE"])("registra %s sem vincular usuario", async (result) => {
    python.mockResolvedValue(Response.json({ result }));
    const response = await upload();

    expect(response.status).toBe(403);
    expect(response.body).toMatchObject({ allowed: false, reason: result });
    expect(db.authorization.updateMany).not.toHaveBeenCalled();
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
