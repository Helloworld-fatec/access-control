// backend/src/controllers/locations.controller.ts
import type { Request, Response } from "express";
import type { Prisma } from "../generated/prisma/client.js";
import { prisma } from "../config/prisma.js";
import { AppError } from "../middlewares/error.middleware.js";
import {
  createLocationSchema,
  idParamSchema,
  listLocationsQuerySchema,
  updateLocationSchema,
} from "../models/dtos/index.js";
import { paginate, toLocationResponse } from "../models/index.js";

const notFound = () => new AppError(404, "Local não encontrado", "LOCATION_NOT_FOUND");

// GET /locations
export async function listLocations(req: Request, res: Response) {
  const q = listLocationsQuerySchema.parse(req.query);

  const where: Prisma.locationWhereInput = q.search
    ? {
        OR: [
          { building: { contains: q.search, mode: "insensitive" } },
          { entrance: { contains: q.search, mode: "insensitive" } },
          { door: { contains: q.search, mode: "insensitive" } },
          { turnstile: { contains: q.search, mode: "insensitive" } },
        ],
      }
    : {};

  const [rows, total] = await prisma.$transaction([
    prisma.location.findMany({
      where,
      orderBy: [{ building: "asc" }, { entrance: "asc" }, { door: "asc" }],
      skip: (q.page - 1) * q.pageSize,
      take: q.pageSize,
    }),
    prisma.location.count({ where }),
  ]);

  res.json(paginate(rows.map(toLocationResponse), total, q.page, q.pageSize));
}

// GET /locations/:id
export async function getLocation(req: Request, res: Response) {
  const { id } = idParamSchema.parse(req.params);

  const location = await prisma.location.findUnique({ where: { id } });
  if (!location) throw notFound();

  res.json(toLocationResponse(location));
}

// POST /locations
export async function createLocation(req: Request, res: Response) {
  const data = createLocationSchema.parse(req.body);

  const location = await prisma.location.create({ data });

  res.status(201).json(toLocationResponse(location));
}

// PUT /locations/:id
export async function updateLocation(req: Request, res: Response) {
  const { id } = idParamSchema.parse(req.params);
  const data = updateLocationSchema.parse(req.body);

  const location = await prisma.location.update({ where: { id }, data });

  res.json(toLocationResponse(location));
}

// DELETE /locations/:id
export async function deleteLocation(req: Request, res: Response) {
  const { id } = idParamSchema.parse(req.params);

  const [terminals, authorizations] = await Promise.all([
    prisma.terminal.count({ where: { locationId: id } }),
    prisma.authorization.count({ where: { locationId: id } }),
  ]);
  if (terminals > 0 || authorizations > 0) {
    throw new AppError(
      409,
      "Local em uso por terminais ou autorizações e não pode ser removido",
      "LOCATION_IN_USE",
    );
  }

  await prisma.location.delete({ where: { id } });

  res.status(204).send();
}
