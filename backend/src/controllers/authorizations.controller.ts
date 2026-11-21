// backend/src/controllers/authorizations.controller.ts
import type { Request, Response } from "express";
import type { Prisma } from "../generated/prisma/client.js";
import { prisma } from "../config/prisma.js";
import { AppError } from "../middlewares/error.middleware.js";
import { AUTHORIZATION_STATUSES, USER_ROLES } from "../types/index.js";
import {
  cancelAuthorizationSchema,
  createAuthorizationSchema,
  idParamSchema,
  listAuthorizationsQuerySchema,
} from "../models/dtos/index.js";
import { paginate, toAuthorizationResponse, todayInSaoPaulo } from "../models/index.js";
import { paginationSchema } from "../models/dtos/common.dto.js";

// @db.Date: gravamos sempre a meia-noite UTC do dia informado.
const toDate = (yyyyMmDd: string) => new Date(`${yyyyMmDd}T00:00:00.000Z`);

const include = {
  location: true,
  user: { select: { id: true, name: true } },
} satisfies Prisma.authorizationInclude;

export async function listMyAuthorizations(req: Request, res: Response) {
  if (!req.auth) throw new AppError(401, "User not authenticated", "UNAUTHORIZED");
  const q = paginationSchema.parse(req.query);
  const where: Prisma.authorizationWhereInput = { userId: req.auth.userId };
  const [rows, total] = await prisma.$transaction([
    prisma.authorization.findMany({
      where,
      include,
      orderBy: { createdAt: "desc" },
      skip: (q.page - 1) * q.pageSize,
      take: q.pageSize,
    }),
    prisma.authorization.count({ where }),
  ]);
  res.json(paginate(rows.map(toAuthorizationResponse), total, q.page, q.pageSize));
}

/** TODO: remover quando existir login (o admin virá do token). */
async function assertAdmin(userId: string, field: string) {
  const admin = await prisma.user.findUnique({
    where: { id: userId },
    select: { role: true, active: true },
  });
  if (!admin || admin.role !== USER_ROLES.ADMIN || !admin.active) {
    throw new AppError(400, `${field} deve ser o id de um administrador ativo`, "INVALID_ADMIN");
  }
}

// GET /authorizations
export async function listAuthorizations(req: Request, res: Response) {
  const q = listAuthorizationsQuerySchema.parse(req.query);
  const today = toDate(todayInSaoPaulo());

  const and: Prisma.authorizationWhereInput[] = [];
  if (q.userId) and.push({ userId: q.userId });
  if (q.locationId) and.push({ locationId: q.locationId });
  if (q.from) and.push({ endDate: { gte: toDate(q.from) } }); // período intersecta [from, to]
  if (q.to) and.push({ startDate: { lte: toDate(q.to) } });

  // EXPIRED não existe no banco: é ACTIVE com endDate no passado.
  if (q.status === "CANCELED") {
    and.push({ status: AUTHORIZATION_STATUSES.CANCELED });
  } else if (q.status === "ACTIVE") {
    and.push({ status: AUTHORIZATION_STATUSES.ACTIVE, endDate: { gte: today } });
  } else if (q.status === "EXPIRED") {
    and.push({ status: AUTHORIZATION_STATUSES.ACTIVE, endDate: { lt: today } });
  }

  const where: Prisma.authorizationWhereInput = { AND: and };

  const [rows, total] = await prisma.$transaction([
    prisma.authorization.findMany({
      where,
      include,
      orderBy: { createdAt: "desc" },
      skip: (q.page - 1) * q.pageSize,
      take: q.pageSize,
    }),
    prisma.authorization.count({ where }),
  ]);

  res.json(paginate(rows.map(toAuthorizationResponse), total, q.page, q.pageSize));
}

// GET /authorizations/:id
export async function getAuthorization(req: Request, res: Response) {
  const { id } = idParamSchema.parse(req.params);

  const authorization = await prisma.authorization.findUnique({ where: { id }, include });
  if (!authorization) {
    throw new AppError(404, "Autorização não encontrada", "AUTHORIZATION_NOT_FOUND");
  }

  res.json(toAuthorizationResponse(authorization));
}

// POST /authorizations
export async function createAuthorization(req: Request, res: Response) {
  if (!req.auth) throw new AppError(401, "User not authenticated", "UNAUTHORIZED");
  const dto = createAuthorizationSchema.parse(req.body);

  const [user, location] = await Promise.all([
    prisma.user.findUnique({
      where: { id: dto.userId },
      select: { id: true, active: true },
    }),
    prisma.location.findUnique({ where: { id: dto.locationId }, select: { id: true } }),
  ]);
  if (!user) throw new AppError(404, "Usuário não encontrado", "USER_NOT_FOUND");
  if (!user.active) throw new AppError(409, "Usuário inativo", "USER_INACTIVE");
  if (!location) throw new AppError(404, "Local não encontrado", "LOCATION_NOT_FOUND");
  await assertAdmin(req.auth.userId, "createdById");

  const authorization = await prisma.authorization.create({
    data: {
      userId: dto.userId,
      locationId: dto.locationId,
      startDate: toDate(dto.startDate),
      endDate: toDate(dto.endDate),
      startTime: dto.startTime,
      endTime: dto.endTime,
      maxUses: dto.maxUses ?? null,
      createdById: req.auth.userId,
    },
    include,
  });

  res.status(201).json(toAuthorizationResponse(authorization));
}

// PATCH /authorizations/:id/cancel
export async function cancelAuthorization(req: Request, res: Response) {
  if (!req.auth) throw new AppError(401, "User not authenticated", "UNAUTHORIZED");
  const { id } = idParamSchema.parse(req.params);
  cancelAuthorizationSchema.parse(req.body);

  await assertAdmin(req.auth.userId, "canceledById");

  // Atômico: só cancela se ainda estiver ACTIVE.
  const { count } = await prisma.authorization.updateMany({
    where: { id, status: AUTHORIZATION_STATUSES.ACTIVE },
    data: {
      status: AUTHORIZATION_STATUSES.CANCELED,
      canceledAt: new Date(),
      canceledById: req.auth.userId,
    },
  });

  if (count === 0) {
    const exists = await prisma.authorization.findUnique({ where: { id }, select: { id: true } });
    if (!exists) {
      throw new AppError(404, "Autorização não encontrada", "AUTHORIZATION_NOT_FOUND");
    }
    throw new AppError(409, "Autorização já está cancelada", "ALREADY_CANCELED");
  }

  const authorization = await prisma.authorization.findUniqueOrThrow({
    where: { id },
    include,
  });

  res.json(toAuthorizationResponse(authorization));
}
