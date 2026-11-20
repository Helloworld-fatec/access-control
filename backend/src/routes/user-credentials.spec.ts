import jwt from "jsonwebtoken";
import request from "supertest";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { env } from "../config/env.js";
import { Prisma } from "../generated/prisma/client.js";
import { app } from "../index.js";
import { removePhotoFile } from "../config/photos.js";

const db = vi.hoisted(() => ({
  findUser: vi.fn(),
  deleteUser: vi.fn(),
  findPhoto: vi.fn(),
  createCredential: vi.fn(),
  findCredential: vi.fn(),
}));

vi.mock("../config/prisma.js", () => {
  const client = {
    user: { findUnique: db.findUser, delete: db.deleteUser },
    userphoto: { findUnique: db.findPhoto },
    nfccredential: {
      createMany: db.createCredential,
      findUnique: db.findCredential,
    },
  };
  return { prisma: { ...client, $transaction: (fn: (tx: typeof client) => unknown) => fn(client) } };
});
vi.mock("../config/photos.js", () => ({
  removePhotoFile: vi.fn(),
  resolvePhotoPath: vi.fn(),
}));

const userId = "14825695-6cdb-4e40-a33e-94045475eabb";
const userPath = `/api/users/${userId}`;
const credentialPath = `${userPath}/nfc-credential`;
const codeHex = "04A3F9";
const api = request(app);

function bearer() {
  return `Bearer ${jwt.sign({ role: "ADMIN" }, env.JWT_SECRET, { subject: "admin" })}`;
}

function link(code: string) {
  return api.put(credentialPath).set("Authorization", bearer()).send({ codeHex: code });
}

function prismaError(code: string) {
  return new Prisma.PrismaClientKnownRequestError("database error", { code, clientVersion: "test" });
}

beforeEach(() => {
  vi.resetAllMocks();
  db.findUser.mockResolvedValue({ role: "ADMIN", active: true });
});

describe("user administration", () => {
  it("requires authentication for listing and editing users", async () => {
    expect((await api.get("/api/users")).status).toBe(401);
    expect((await api.put(userPath).send({ name: "Test user" })).status).toBe(401);
  });

  it("checks the current role before creating the credential", async () => {
    db.findUser.mockResolvedValue({ role: "RESIDENT", active: true });
    expect((await link(codeHex)).status).toBe(403);
    expect(db.createCredential).not.toHaveBeenCalled();
  });

  it("passes the exact code to the database and accepts a retry", async () => {
    db.createCredential.mockResolvedValueOnce({ count: 1 }).mockResolvedValueOnce({ count: 0 });
    db.findCredential.mockResolvedValue({ codeHex, status: "PENDING" });
    for (let attempt = 0; attempt < 2; attempt++) {
      const response = await link(codeHex);
      expect(response.status).toBe(200);
      expect(response.body).toEqual({ status: "PENDING" });
    }
    expect(db.createCredential).toHaveBeenCalledWith({
      data: { userId, codeHex },
      skipDuplicates: true,
    });
  });

  it("returns only credential status in the user detail", async () => {
    db.findUser.mockResolvedValueOnce({ role: "ADMIN", active: true })
      .mockResolvedValueOnce({
        id: userId, role: "RESIDENT", nfcTags: [], faceTemplate: { id: "face" },
        photo: null, nfcCredential: { status: "PENDING", codeHex },
      });
    const response = await api.get(userPath).set("Authorization", bearer());
    expect(response.status).toBe(200);
    expect(response.body).toMatchObject({ hasFace: true, nfcCredential: { status: "PENDING" } });
    expect(response.text).not.toContain(codeHex);
  });

  it.each(["04a3f9", "04A3F90", "4A3F9", "04A3G9", " 04A3F9"])(
    "rejects malformed code %s",
    async (code) => {
      expect((await link(code)).status).toBe(400);
      expect(db.createCredential).not.toHaveBeenCalled();
    },
  );

  it("distinguishes a duplicate code from an existing credential on this user", async () => {
    db.createCredential.mockResolvedValue({ count: 0 });
    db.findCredential.mockResolvedValueOnce(null)
      .mockResolvedValueOnce({ codeHex: "111111", status: "PENDING" });
    const duplicate = await link(codeHex);
    expect(duplicate.status).toBe(409);
    expect(duplicate.body.error.code).toBe("NFC_CODE_CONFLICT");
    const existing = await link(codeHex);
    expect(existing.status).toBe(409);
    expect(existing.body.error.code).toBe("NFC_CREDENTIAL_EXISTS");
  });

  it("returns 404 when the credential target no longer exists", async () => {
    db.createCredential.mockRejectedValue(prismaError("P2003"));
    expect((await link(codeHex)).status).toBe(404);
  });

  it("removes the legacy photo file after deleting the user", async () => {
    db.findPhoto.mockResolvedValue({ filePath: "legacy.jpg" });
    db.deleteUser.mockImplementation(async () => {
      expect(removePhotoFile).not.toHaveBeenCalled();
      return { id: userId };
    });
    const response = await api.delete(userPath).set("Authorization", bearer());
    expect(response.status).toBe(204);
    expect(db.deleteUser).toHaveBeenCalledWith({ where: { id: userId }, select: { id: true } });
    expect(removePhotoFile).toHaveBeenCalledWith("legacy.jpg");
  });

  it("preserves the photo when authorization references block the deletion", async () => {
    db.findPhoto.mockResolvedValue({ filePath: "legacy.jpg" });
    db.deleteUser.mockRejectedValue(prismaError("P2003"));
    const response = await api.delete(userPath).set("Authorization", bearer());
    expect(response.status).toBe(409);
    expect(response.body.error.code).toBe("USER_DELETE_CONFLICT");
    expect(removePhotoFile).not.toHaveBeenCalled();
  });
});
