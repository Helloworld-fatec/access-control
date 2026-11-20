import jwt from "jsonwebtoken";
import request from "supertest";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { env } from "../config/env.js";
import { app } from "../index.js";

const db = vi.hoisted(() => ({ findUnique: vi.fn(), upsert: vi.fn() }));
vi.mock("../config/prisma.js", () => ({
  prisma: { user: { findUnique: db.findUnique }, facetemplate: { upsert: db.upsert } },
}));

const userId = "14825695-6cdb-4e40-a33e-94045475eabb";
const endpoint = `/api/users/${userId}/face`;
// Express checks the JPEG signature; full decoding is handled by the mocked extractor.
const photo = Buffer.from([0xff, 0xd8, 0xff, 0xd9]);
const result = { embedding: Array.from({ length: 1764 }, () => 0.25), modelVersion: "hog-v1" };
const fetchFace = vi.fn<typeof fetch>();

function upload(consent = "true") {
  const token = jwt.sign({ role: "ADMIN" }, env.JWT_SECRET, { subject: "admin" });
  return request(app).post(endpoint).set("Authorization", `Bearer ${token}`).field("consent", consent);
}

beforeEach(() => {
  vi.resetAllMocks();
  vi.stubGlobal("fetch", fetchFace);
  db.findUnique.mockResolvedValueOnce({ active: true, role: "ADMIN" });
  db.findUnique.mockResolvedValueOnce({ photo: null });
});
afterEach(() => vi.unstubAllGlobals());

describe("POST /api/users/:id/face", () => {
  it("forwards only the JPEG and saves the validated descriptor", async () => {
    fetchFace.mockResolvedValue(Response.json(result));

    const response = await upload().attach("photo", photo, "face.jpg");
    expect(response.status).toBe(201);
    expect(response.body).toEqual({ hasFace: true, hasPhoto: false });
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
  });

  it("reports an existing saved photo without replacing it", async () => {
    db.findUnique.mockReset()
      .mockResolvedValueOnce({ active: true, role: "ADMIN" })
      .mockResolvedValueOnce({ photo: { id: "old-photo" } });
    fetchFace.mockResolvedValue(Response.json(result));
    const response = await upload().attach("photo", photo, "face.jpg");
    expect(response.status).toBe(201);
    expect(response.body.hasPhoto).toBe(true);
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

  it("reports database failures without including database input", async () => {
    fetchFace.mockResolvedValue(Response.json(result));
    db.upsert.mockRejectedValue(new Error("private database input"));
    const response = await upload().attach("photo", photo, "face.jpg");
    expect(response.status).toBe(500);
    expect(response.body.error.code).toBe("FACE_PERSISTENCE_FAILED");
    expect(response.text).not.toContain("private database input");
  });
});
