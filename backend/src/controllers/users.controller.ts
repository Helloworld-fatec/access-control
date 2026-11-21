// backend/src/controllers/users.controller.ts
import fs from "node:fs";
import type { Request, Response } from "express";
import bcrypt from "bcrypt";
import { Prisma } from "../generated/prisma/client.js";
import { prisma } from "../config/prisma.js";
import { env } from "../config/env.js";
import { removePhotoFile, resolvePhotoPath, savePhotoFile } from "../config/photos.js";
import { AppError } from "../middlewares/error.middleware.js";
import { extractFace } from "../services/face-recognition.service.js";
import {
  createNfcTagSchema,
  createUserSchema,
  idParamSchema,
  linkNfcCredentialSchema,
  listUsersQuerySchema,
  nfcTagParamsSchema,
  updateUserSchema,
  updateUserStatusSchema,
  upsertFaceSchema,
} from "../models/dtos/index.js";
import {
  paginate,
  toNfcTagResponse,
  toUserDetailResponse,
  toUserResponse,
} from "../models/index.js";

const userNotFound = () => new AppError(404, "Usuário não encontrado", "USER_NOT_FOUND");

/** E-mail ou documento já usados por outro usuário? */
async function assertUnique(
  email: string | undefined,
  document: string | undefined,
  ignoreId?: string,
) {
  const or: Prisma.userWhereInput[] = [];
  if (email) or.push({ email });
  if (document) or.push({ document });
  if (or.length === 0) return;

  const found = await prisma.user.findFirst({
    where: { OR: or, ...(ignoreId ? { NOT: { id: ignoreId } } : {}) },
    select: { id: true },
  });
  if (found) {
    throw new AppError(409, "E-mail ou documento já cadastrado", "USER_CONFLICT");
  }
}

// GET /users
export async function listUsers(req: Request, res: Response) {
  const q = listUsersQuerySchema.parse(req.query);

  const where: Prisma.userWhereInput = {
    ...(q.role ? { role: q.role } : {}),
    ...(q.active !== undefined ? { active: q.active } : {}),
    ...(q.search
      ? {
          OR: [
            { name: { contains: q.search, mode: "insensitive" } },
            { document: { contains: q.search } },
          ],
        }
      : {}),
  };

  const [rows, total] = await prisma.$transaction([
    prisma.user.findMany({
      where,
      include: { photo: { select: { id: true } } },
      orderBy: { name: "asc" },
      skip: (q.page - 1) * q.pageSize,
      take: q.pageSize,
    }),
    prisma.user.count({ where }),
  ]);

  const data = rows.map((user) => ({
    ...toUserResponse(user),
    hasPhoto: user.photo != null,
  }));
  res.json(paginate(data, total, q.page, q.pageSize));
}

// GET /users/:id
export async function getUser(req: Request, res: Response) {
  const { id } = idParamSchema.parse(req.params);

  const user = await prisma.user.findUnique({
    where: { id },
    include: {
      nfcTags: { orderBy: { createdAt: "desc" } },
      nfcCredential: { select: { status: true } },
      faceTemplate: { select: { id: true } }, // nunca devolve o embedding
      photo: { select: { id: true } },
    },
  });
  if (!user) throw userNotFound();

  res.json(toUserDetailResponse(user));
}

// POST /users
export async function createUser(req: Request, res: Response) {
  const { password, ...data } = createUserSchema.parse(req.body);

  await assertUnique(data.email, data.document);

  const passwordHash = await bcrypt.hash(password, env.BCRYPT_ROUNDS);
  const user = await prisma.user.create({ data: { ...data, passwordHash } });

  res.status(201).json(toUserResponse(user));
}

// PUT /users/:id
export async function updateUser(req: Request, res: Response) {
  const { id } = idParamSchema.parse(req.params);
  const { password, ...data } = updateUserSchema.parse(req.body);

  await assertUnique(data.email, data.document, id);

  const passwordHash = password
    ? await bcrypt.hash(password, env.BCRYPT_ROUNDS)
    : undefined;

  // P2025 (id inexistente) vira 404 no errorHandler
  const user = await prisma.user.update({
    where: { id },
    data: { ...data, ...(passwordHash ? { passwordHash } : {}) },
  });

  res.json(toUserResponse(user));
}

// DELETE /users/:id
export async function deleteUser(req: Request, res: Response) {
  const { id } = idParamSchema.parse(req.params);
  const photoPath = await prisma.$transaction(async (tx) => {
    await lockPhotoOwner(tx, id);
    const photo = await tx.userphoto.findUnique({
      where: { userId: id },
      select: { filePath: true },
    });
    try {
      await tx.user.delete({ where: { id }, select: { id: true } });
    } catch (err) {
      if (err instanceof Prisma.PrismaClientKnownRequestError) {
        if (err.code === "P2025") throw userNotFound();
        if (err.code === "P2003") {
          throw new AppError(
            409,
            "Usuários que criaram autorizações ainda vinculadas não podem ser excluídos",
            "USER_DELETE_CONFLICT",
          );
        }
      }
      throw err;
    }
    return photo?.filePath;
  });

  await removePhotoFile(photoPath);
  res.status(204).send();
}

// PATCH /users/:id/status
export async function updateUserStatus(req: Request, res: Response) {
  const { id } = idParamSchema.parse(req.params);
  const { active } = updateUserStatusSchema.parse(req.body);

  const user = await prisma.user.update({ where: { id }, data: { active } });

  res.json(toUserResponse(user));
}

// ───────────── Tags NFC ─────────────

// POST /users/:id/tags
export async function addTag(req: Request, res: Response) {
  const { id } = idParamSchema.parse(req.params);
  const { uid } = createNfcTagSchema.parse(req.body);

  const user = await prisma.user.findUnique({ where: { id }, select: { id: true } });
  if (!user) throw userNotFound();

  // Mensagem genérica: não revela de quem é a tag.
  const existing = await prisma.nfctag.findUnique({ where: { uid }, select: { id: true } });
  if (existing) {
    throw new AppError(409, "Esta tag já está cadastrada", "TAG_CONFLICT");
  }

  const tag = await prisma.nfctag.create({ data: { uid, userId: id } });

  res.status(201).json(toNfcTagResponse(tag));
}

// DELETE /users/:id/tags/:tagId
export async function removeTag(req: Request, res: Response) {
  const { id, tagId } = nfcTagParamsSchema.parse(req.params);

  const { count } = await prisma.nfctag.deleteMany({ where: { id: tagId, userId: id } });
  if (count === 0) throw new AppError(404, "Tag não encontrada", "TAG_NOT_FOUND");

  res.status(204).send();
}

// PUT /users/:id/nfc-credential
export async function linkNfcCredential(req: Request, res: Response) {
  const { id } = idParamSchema.parse(req.params);
  const { codeHex } = linkNfcCredentialSchema.parse(req.body);
  try {
    const credential = await prisma.$transaction(async (tx) => {
      // A unicidade no banco resolve cadastros simultâneos e retentativas.
      await tx.nfccredential.createMany({
        data: { userId: id, codeHex },
        skipDuplicates: true,
      });
      return tx.nfccredential.findUnique({
        where: { userId: id },
        select: { codeHex: true, status: true },
      });
    });
    if (!credential) {
      throw new AppError(409, "Este código NFC já está em uso", "NFC_CODE_CONFLICT");
    }
    if (credential.codeHex !== codeHex) {
      throw new AppError(409, "Este usuário já tem um código NFC", "NFC_CREDENTIAL_EXISTS");
    }
    res.json({ status: credential.status });
  } catch (err) {
    if (err instanceof AppError) throw err;
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === "P2003") {
      throw userNotFound();
    }
    // Erros brutos do Prisma podem incluir o código recebido.
    throw new AppError(500, "Não foi possível gravar o código NFC", "NFC_CREDENTIAL_WRITE_FAILED");
  }
}

// ───────────── Rosto e foto ─────────────

async function lockPhotoOwner(tx: Prisma.TransactionClient, id: string): Promise<void> {
  // Serialize uploads and deletions even when no photo row exists yet.
  const users = await tx.$queryRaw<{ id: string }[]>`
    SELECT id FROM users WHERE id = ${id} FOR UPDATE
  `;
  if (users.length === 0) throw userNotFound();
}

/**
 * POST /users/:id/face  (multipart/form-data)
 * Campos: consent=true e photo (JPEG).
 * O middleware valida o upload e mantém a foto em memória.
 */
export async function upsertFace(req: Request, res: Response) {
  const { id } = idParamSchema.parse(req.params);
  upsertFaceSchema.parse(req.body);
  const photo = req.file?.buffer;
  if (!photo) throw new AppError(400, "A foto é obrigatória", "PHOTO_REQUIRED");

  const user = await prisma.user.findUnique({
    where: { id },
    select: { id: true },
  });
  if (!user) throw userNotFound();

  const consentAt = new Date();
  const descriptor = await extractFace(photo);
  const faceData = { ...descriptor, consentAt };
  let filePath: string | undefined;
  let oldPath: string | undefined;
  try {
    const savedPath = await savePhotoFile(photo);
    filePath = savedPath;
    oldPath = await prisma.$transaction(async (tx) => {
      await lockPhotoOwner(tx, id);
      const previous = await tx.userphoto.findUnique({
        where: { userId: id },
        select: { filePath: true },
      });
      await tx.facetemplate.upsert({
        where: { userId: id },
        create: { userId: id, ...faceData },
        update: faceData,
        select: { id: true },
      });
      const photoData = { filePath: savedPath, mimeType: "image/jpeg" };
      await tx.userphoto.upsert({
        where: { userId: id },
        create: { userId: id, ...photoData },
        update: photoData,
        select: { id: true },
      });
      return previous?.filePath;
    });
  } catch (error) {
    await removePhotoFile(filePath);
    if (error instanceof AppError) throw error;
    // O erro bruto do Prisma pode incluir os valores enviados na operação.
    throw new AppError(500, "Não foi possível gravar o cadastro facial", "FACE_PERSISTENCE_FAILED");
  }

  await removePhotoFile(oldPath);
  res.status(201).json({ hasFace: true, hasPhoto: true });
}

// DELETE /users/:id/face  (exclusão dos dados biométricos, LGPD)
export async function deleteFace(req: Request, res: Response) {
  const { id } = idParamSchema.parse(req.params);

  const photoPath = await prisma.$transaction(async (tx) => {
    await lockPhotoOwner(tx, id);
    const photo = await tx.userphoto.findUnique({
      where: { userId: id },
      select: { filePath: true },
    });
    await tx.facetemplate.deleteMany({ where: { userId: id } });
    await tx.userphoto.deleteMany({ where: { userId: id } });
    return photo?.filePath;
  });
  await removePhotoFile(photoPath);

  res.status(204).send();
}

// GET /users/:id/photo
export async function getPhoto(req: Request, res: Response) {
  const { id } = idParamSchema.parse(req.params);
  await sendUserPhoto(id, res);
}

export async function getOwnPhoto(req: Request, res: Response) {
  if (!req.auth) throw new AppError(401, "User not authenticated", "UNAUTHORIZED");
  await sendUserPhoto(req.auth.userId, res);
}

async function sendUserPhoto(id: string, res: Response) {
  const photo = await prisma.userphoto.findUnique({ where: { userId: id } });
  if (!photo) throw new AppError(404, "Foto não encontrada", "PHOTO_NOT_FOUND");

  const absolutePath = resolvePhotoPath(photo.filePath);
  try {
    await fs.promises.access(absolutePath, fs.constants.R_OK);
  } catch {
    throw new AppError(404, "Arquivo da foto não encontrado", "PHOTO_NOT_FOUND");
  }

  res.type(photo.mimeType);
  res.set("Cache-Control", "private, no-store");
  res.sendFile(absolutePath);
}
