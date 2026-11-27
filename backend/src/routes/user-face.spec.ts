import { mkdtemp, readFile, readdir, rmdir, unlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import jwt from "jsonwebtoken";
import request from "supertest";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { env } from "../config/env.js";
import { app } from "../index.js";

const db = vi.hoisted(() => ({
  findUnique: vi.fn(),
  findUsers: vi.fn(),
  countUsers: vi.fn(),
  upsert: vi.fn(),
  findPhoto: vi.fn(),
  upsertPhoto: vi.fn(),
  deleteFace: vi.fn(),
  deletePhoto: vi.fn(),
  lockUser: vi.fn(),
  transaction: vi.fn(),
}));
vi.mock("../config/prisma.js", () => {
  const client = {
    user: { findUnique: db.findUnique, findMany: db.findUsers, count: db.countUsers },
    facetemplate: { upsert: db.upsert, deleteMany: db.deleteFace },
    userphoto: { findUnique: db.findPhoto, upsert: db.upsertPhoto, deleteMany: db.deletePhoto },
    $queryRaw: db.lockUser,
  };
  return {
    prisma: {
      ...client,
      $transaction: (work: ((tx: typeof client) => unknown) | Promise<unknown>[]) =>
        Array.isArray(work) ? Promise.all(work) : db.transaction(() => work(client)),
    },
  };
});

const userId = "14825695-6cdb-4e40-a33e-94045475eabb";
const endpoint = `/api/users/${userId}/face`;
// Express checks the JPEG signature; full decoding is handled by the mocked extractor.
const photo = Buffer.from([0xff, 0xd8, 0xff, 0xd9]);
const result = { embedding: Array.from({ length: 1764 }, () => 0.25), modelVersion: "hog-v1" };
const fetchFace = vi.fn<typeof fetch>();
const originalPhotosDir = env.PHOTOS_DIR;
let photosDir: string;

function bearer(role = "ADMIN", subject = "admin") {
  return `Bearer ${jwt.sign({ role }, env.JWT_SECRET, { subject })}`;
}

function upload(consent = "true") {
  return request(app).post(endpoint).set("Authorization", bearer()).field("consent", consent);
}

beforeEach(async () => {
  vi.resetAllMocks();
  photosDir = await mkdtemp(join(tmpdir(), "access-control-photos-"));
  env.PHOTOS_DIR = photosDir;
  vi.stubGlobal("fetch", fetchFace);
  db.findUnique.mockResolvedValue({ id: userId, active: true, role: "ADMIN" });
  db.lockUser.mockResolvedValue([{ id: userId }]);
  db.transaction.mockImplementation((work) => work());
});

describe("leitura das fotos de usuários", () => {
  const ownPhoto = "/api/users/me/photo";
  const resident = bearer("RESIDENT", userId);

  it("consulta a própria foto pelo JWT e reserva a consulta por ID ao administrador", async () => {
    await writeFile(join(photosDir, "own.jpg"), photo);
    db.findUnique.mockResolvedValue({ active: true, role: "RESIDENT" });
    db.findPhoto.mockResolvedValue({ filePath: "own.jpg", mimeType: "image/jpeg" });
    const response = await request(app).get(ownPhoto)
      .query({ userId: "another-user" })
      .set("Authorization", resident);
    expect(response.status).toBe(200);
    expect(response.body).toEqual(photo);
    expect(db.findPhoto).toHaveBeenCalledExactlyOnceWith({ where: { userId } });
    expect((await request(app).get(`/api/users/${userId}/photo`)
      .set("Authorization", resident)).status).toBe(403);
    expect(db.findPhoto).toHaveBeenCalledTimes(1);
  });

  it("requer sessão e retorna 404 quando o usuário não tem foto", async () => {
    expect((await request(app).get(ownPhoto)).status).toBe(401);
    const response = await request(app).get(ownPhoto).set("Authorization", resident);
    expect(response.status).toBe(404);
    expect(response.body.error.code).toBe("PHOTO_NOT_FOUND");
  });

  it("inclui apenas o indicador de foto na listagem administrativa", async () => {
    db.findUsers.mockResolvedValue([
      { id: userId, photo: { id: "photo-id" } },
      { id: "another-user", photo: null },
    ]);
    db.countUsers.mockResolvedValue(2);
    const response = await request(app).get("/api/users").set("Authorization", bearer());
    expect(response.status).toBe(200);
    expect(response.body.data).toEqual([
      { id: userId, hasPhoto: true },
      { id: "another-user", hasPhoto: false },
    ]);
  });
});
afterEach(async () => {
  vi.unstubAllGlobals();
  env.PHOTOS_DIR = originalPhotosDir;
  for (const file of await readdir(photosDir)) {
    await unlink(join(photosDir, file));
  }
  await rmdir(photosDir);
});

describe("POST /api/users/:id/face", () => {
  it("saves the descriptor and serves the persisted JPEG", async () => {
    fetchFace.mockResolvedValue(Response.json(result));

    const response = await upload().attach("photo", photo, "face.jpg");
    expect(response.status).toBe(201);
    expect(response.body).toEqual({ hasFace: true, hasPhoto: true });
    const [url, options] = fetchFace.mock.calls[0]!;
    expect(url).toEqual(new URL("/extract", env.FACE_RECOGNITION_URL));
    const form = options?.body as FormData;
    expect([...form.keys()]).toEqual(["photo"]);
    expect(Buffer.from(await (form.get("photo") as Blob).arrayBuffer())).toEqual(photo);
    const data = { ...result, consentAt: expect.any(Date) };
    expect(db.upsert).toHaveBeenCalledExactlyOnceWith({
      where: { userId },
      create: { userId, ...data },
      update: data,
      select: { id: true },
    });
    const [filePath] = await readdir(photosDir);
    expect(filePath).toMatch(/^[\da-f-]+\.jpg$/);
    const photoData = { filePath, mimeType: "image/jpeg" };
    expect(db.upsertPhoto).toHaveBeenCalledExactlyOnceWith({
      where: { userId },
      create: { userId, ...photoData },
      update: photoData,
      select: { id: true },
    });
    db.findPhoto.mockResolvedValue(photoData);
    const saved = await request(app).get(`/api/users/${userId}/photo`).set("Authorization", bearer());
    expect(saved.status).toBe(200);
    expect(saved.headers["content-type"]).toBe("image/jpeg");
    expect(saved.body).toEqual(photo);
  });

  it("replaces the previous photo after the transaction succeeds", async () => {
    await writeFile(join(photosDir, "old.jpg"), "old");
    db.findPhoto.mockResolvedValue({ filePath: "old.jpg" });
    fetchFace.mockResolvedValue(Response.json(result));
    const response = await upload().attach("photo", photo, "face.jpg");
    expect(response.status).toBe(201);
    expect(response.body.hasPhoto).toBe(true);
    const files = await readdir(photosDir);
    expect(files).toHaveLength(1);
    expect(files[0]).not.toBe("old.jpg");
    expect(await readFile(join(photosDir, files[0]!))).toEqual(photo);
  });

  it("requires authentication before processing the photo", async () => {
    expect((await request(app).post(endpoint).attach("photo", photo, "face.jpg")).status).toBe(401);
    expect(fetchFace).not.toHaveBeenCalled();
  });

  it("rejects a non-admin before processing the photo", async () => {
    db.findUnique.mockReset().mockResolvedValue({ active: true, role: "RESIDENT" });
    expect((await upload().attach("photo", photo, "face.jpg")).status).toBe(403);
    expect(fetchFace).not.toHaveBeenCalled();
  });

  it("requires a photo", async () => {
    expect((await upload()).body.error.code).toBe("PHOTO_REQUIRED");
    expect(fetchFace).not.toHaveBeenCalled();
    expect(db.upsert).not.toHaveBeenCalled();
  });

  it("requires explicit consent", async () => {
    expect((await upload("false").attach("photo", photo, "face.jpg")).status).toBe(400);
    expect(fetchFace).not.toHaveBeenCalled();
    expect(db.upsert).not.toHaveBeenCalled();
  });

  it("rejects the legacy client-provided embedding", async () => {
    const response = await upload().field("embedding", "[0]").attach("photo", photo, "face.jpg");
    expect(response.status).toBe(400);
    expect(fetchFace).not.toHaveBeenCalled();
  });

  it("rejects a photo above the configured limit", async () => {
    const response = await upload().attach("photo", Buffer.alloc(env.MAX_PHOTO_BYTES + 1), "face.jpg");
    expect(response.status).toBe(413);
    expect(fetchFace).not.toHaveBeenCalled();
  });

  it.each([
    { ...result, modelVersion: "legacy" },
    { ...result, embedding: [0.5] },
    { ...result, embedding: [...result.embedding.slice(1), "0.5"] },
  ])("skips persistence on an invalid extractor response", async (body) => {
    fetchFace.mockResolvedValue(Response.json(body));
    const response = await upload().attach("photo", photo, "face.jpg");
    expect(response.status).toBe(502);
    expect(response.body.error.code).toBe("FACE_SERVICE_INVALID_RESPONSE");
    expect(db.upsert).not.toHaveBeenCalled();
  });

  it("rejects a JSON number that overflows to infinity", async () => {
    const body = JSON.stringify(result).replace("0.25", "1e400");
    fetchFace.mockResolvedValue(new Response(body));
    const response = await upload().attach("photo", photo, "face.jpg");
    expect(response.status).toBe(502);
    expect(db.upsert).not.toHaveBeenCalled();
  });

  it("relays image validation errors without writing to the database", async () => {
    fetchFace.mockResolvedValue(Response.json({ detail: { code: "NO_FACE" } }, { status: 422 }));
    const response = await upload().attach("photo", photo, "face.jpg");
    expect(response.status).toBe(422);
    expect(response.body.error.code).toBe("NO_FACE");
    expect(db.upsert).not.toHaveBeenCalled();
    expect(await readdir(photosDir)).toEqual([]);
  });

  it("leaves the existing descriptor intact if the service is unreachable", async () => {
    fetchFace.mockRejectedValue(new TypeError("fetch failed"));
    const response = await upload().attach("photo", photo, "face.jpg");
    expect(response.status).toBe(502);
    expect(response.body.error.code).toBe("FACE_SERVICE_UNAVAILABLE");
    expect(db.upsert).not.toHaveBeenCalled();
  });

  it("returns a timeout without writing to the database", async () => {
    const timeout = vi.spyOn(AbortSignal, "timeout").mockReturnValue(AbortSignal.abort());
    try {
      fetchFace.mockRejectedValue(new Error("aborted"));
      const response = await upload().attach("photo", photo, "face.jpg");
      expect(response.status).toBe(504);
      expect(response.body.error.code).toBe("FACE_SERVICE_TIMEOUT");
      expect(db.upsert).not.toHaveBeenCalled();
    } finally {
      timeout.mockRestore();
    }
  });

  it("keeps the old JPEG and cleans up the new one on database failure", async () => {
    await writeFile(join(photosDir, "old.jpg"), "old");
    db.findPhoto.mockResolvedValue({ filePath: "old.jpg" });
    fetchFace.mockResolvedValue(Response.json(result));
    db.upsertPhoto.mockRejectedValue(new Error("private database input"));
    const response = await upload().attach("photo", photo, "face.jpg");
    expect(response.status).toBe(500);
    expect(response.body.error.code).toBe("FACE_PERSISTENCE_FAILED");
    expect(response.text).not.toContain("private database input");
    expect(await readdir(photosDir)).toEqual(["old.jpg"]);
  });

  it("leaves the database untouched when the JPEG cannot be written", async () => {
    env.PHOTOS_DIR = join(photosDir, "missing");
    fetchFace.mockResolvedValue(Response.json(result));
    const response = await upload().attach("photo", photo, "face.jpg");
    expect(response.status).toBe(500);
    expect(response.body.error.code).toBe("FACE_PERSISTENCE_FAILED");
    expect(db.transaction).not.toHaveBeenCalled();
  });

  it("removes the photo file when the face record is deleted", async () => {
    await writeFile(join(photosDir, "old.jpg"), photo);
    db.findPhoto.mockResolvedValue({ filePath: "old.jpg" });
    const response = await request(app).delete(endpoint).set("Authorization", bearer());
    expect(response.status).toBe(204);
    expect(db.deleteFace).toHaveBeenCalledWith({ where: { userId } });
    expect(db.deletePhoto).toHaveBeenCalledWith({ where: { userId } });
    expect(await readdir(photosDir)).toEqual([]);
  });
});
