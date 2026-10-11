// backend/src/controllers/users.controller.ts
import fs from "node:fs";
import type { Request, Response } from "express";
import bcrypt from "bcrypt";
import type { Prisma } from "../generated/prisma/client.js";
import { prisma } from "../config/prisma.js";
import { env } from "../config/env.js";
import { removePhotoFile, resolvePhotoPath } from "../config/photos.js";
import { AppError } from "../middlewares/error.middleware.js";
import {
  createNfcTagSchema,
  createUserSchema,
  idParamSchema,
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
  const or: Prisma.UserWhereInput[] = [];
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

  const where: Prisma.UserWhereInput = {
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
      orderBy: { name: "asc" },
      skip: (q.page - 1) * q.pageSize,
      take: q.pageSize,
    }),
    prisma.user.count({ where }),
  ]);

  res.json(paginate(rows.map(toUserResponse), total, q.page, q.pageSize));
}

// GET /users/:id
export async function getUser(req: Request, res: Response) {
  const { id } = idParamSchema.parse(req.params);

  const user = await prisma.user.findUnique({
    where: { id },
    include: {
      nfcTags: { orderBy: { createdAt: "desc" } },
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
  const existing = await prisma.nfcTag.findUnique({ where: { uid }, select: { id: true } });
  if (existing) {
    throw new AppError(409, "Esta tag já está cadastrada", "TAG_CONFLICT");
  }

  const tag = await prisma.nfcTag.create({ data: { uid, userId: id } });

  res.status(201).json(toNfcTagResponse(tag));
}

// DELETE /users/:id/tags/:tagId
export async function removeTag(req: Request, res: Response) {
  const { id, tagId } = nfcTagParamsSchema.parse(req.params);

  const { count } = await prisma.nfcTag.deleteMany({ where: { id: tagId, userId: id } });
  if (count === 0) throw new AppError(404, "Tag não encontrada", "TAG_NOT_FOUND");

  res.status(204).send();
}

// ───────────── Rosto e foto ─────────────

/**
 * POST /users/:id/face  (multipart/form-data)
 * Campos: embedding (JSON), modelVersion, consent. Arquivo opcional: photo.
 * O multer (middleware de upload) já gravou a foto em PHOTOS_DIR antes de chegar aqui.
 */
export async function upsertFace(req: Request, res: Response) {
  const file = req.file;

  try {
    const { id } = idParamSchema.parse(req.params);
    const dto = upsertFaceSchema.parse(req.body);

    const user = await prisma.user.findUnique({
      where: { id },
      select: { id: true, photo: { select: { filePath: true } } },
    });
    if (!user) throw userNotFound();

    const now = new Date();
    const faceData = {
      embedding: dto.embedding,
      modelVersion: dto.modelVersion,
      consentAt: now,
    };

    const ops: Prisma.PrismaPromise<unknown>[] = [
      prisma.faceTemplate.upsert({
        where: { userId: id },
        create: { userId: id, ...faceData },
        update: faceData,
      }),
    ];

    if (file) {
      ops.push(
        prisma.userPhoto.upsert({
          where: { userId: id },
          create: { userId: id, filePath: file.filename, mimeType: file.mimetype },
          update: { filePath: file.filename, mimeType: file.mimetype, updatedAt: now },
        }),
      );
    }

    await prisma.$transaction(ops);

    // Só apaga a foto antiga depois de o banco apontar para a nova.
    if (file && user.photo && user.photo.filePath !== file.filename) {
      await removePhotoFile(user.photo.filePath);
    }

    res.status(201).json({ hasFace: true, hasPhoto: Boolean(file || user.photo) });
  } catch (err) {
    // Falhou depois do upload: não deixa arquivo órfão no disco.
    if (file) await removePhotoFile(file.filename);
    throw err;
  }
}

// DELETE /users/:id/face  (exclusão dos dados biométricos, LGPD)
export async function deleteFace(req: Request, res: Response) {
  const { id } = idParamSchema.parse(req.params);

  const user = await prisma.user.findUnique({
    where: { id },
    select: { id: true, photo: { select: { filePath: true } } },
  });
  if (!user) throw userNotFound();

  await prisma.$transaction([
    prisma.faceTemplate.deleteMany({ where: { userId: id } }),
    prisma.userPhoto.deleteMany({ where: { userId: id } }),
  ]);
  await removePhotoFile(user.photo?.filePath);

  res.status(204).send();
}

// GET /users/:id/photo
// TODO: exigir autenticação quando existir login (a pasta nunca é servida como estática).
export async function getPhoto(req: Request, res: Response) {
  const { id } = idParamSchema.parse(req.params);

  const photo = await prisma.userPhoto.findUnique({ where: { userId: id } });
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
