import { Router } from "express";
import { z } from "zod";
import { prisma } from "../config/prisma.js";
import type { Prisma } from "../generated/prisma/client.js";
import { authenticate, requireAdmin } from "../middlewares/auth.middleware.js";
import { AppError, asyncHandler } from "../middlewares/error.middleware.js";
import { paginate } from "../models/index.js";
import { idParamSchema, paginationSchema } from "../models/dtos/common.dto.js";
import { checkoutVisit, getVisit, toVisitResponse, visitSelect } from "../services/visits.service.js";
import { startVisitPokemonDraw } from "../services/pokemon-draw.service.js";
import { getPokemon } from "../services/pokemon-catalog.service.js";

const listVisitsQuery = paginationSchema.extend({
  status: z.enum(["INSIDE", "EXITED"]).default("INSIDE"),
  locationId: z.uuid().optional(),
  search: z.string().trim().max(120).optional(),
});

export const visitRoutes = Router();
visitRoutes.use(authenticate, requireAdmin);

visitRoutes.get("/", asyncHandler(async (req, res) => {
  const { status, locationId, search, page, pageSize } = listVisitsQuery.parse(req.query);
  const inside = status === "INSIDE";
  const where: Prisma.visitWhereInput = {
    ...(inside ? { exitedAt: null, userId: { not: null } } : { exitedAt: { not: null } }),
    ...(locationId ? { locationId } : {}),
    ...(search ? { user: { name: { contains: search, mode: "insensitive" } } } : {}),
  };
  const [visits, total] = await prisma.$transaction([
    prisma.visit.findMany({
      where,
      orderBy: [inside ? { enteredAt: "desc" } : { exitedAt: "desc" }, { id: "desc" }],
      skip: (page - 1) * pageSize,
      take: pageSize,
      select: visitSelect,
    }),
    prisma.visit.count({ where }),
  ], { isolationLevel: "RepeatableRead" });

  res.json(paginate(visits.map(toVisitResponse), total, page, pageSize));
}));

visitRoutes.get("/:id", asyncHandler(async (req, res) => {
  const { id } = idParamSchema.parse(req.params);
  res.set("Cache-Control", "no-store").json(await getVisit(id));
}));

visitRoutes.post("/:id/checkout", asyncHandler(async (req, res) => {
  const { id } = idParamSchema.parse(req.params);
  if (!req.auth) throw new AppError(401, "Usuário não autenticado", "UNAUTHORIZED");
  res.json(await checkoutVisit(id, req.auth.userId, "SIMPLE"));
}));

visitRoutes.post("/:id/pokemon/draw", asyncHandler(async (req, res) => {
  const { id } = idParamSchema.parse(req.params);
  const draw = await startVisitPokemonDraw(id);
  res.json({ visitId: draw.visitId, drawnAt: draw.drawnAt, pokemon: await getPokemon(draw.pokemonId) });
}));

visitRoutes.post("/:id/pokemon/claim", asyncHandler(async (req, res) => {
  const { id } = idParamSchema.parse(req.params);
  if (!req.auth) throw new AppError(401, "Usuário não autenticado", "UNAUTHORIZED");
  res.json(await checkoutVisit(id, req.auth.userId, "POKEMON"));
}));
