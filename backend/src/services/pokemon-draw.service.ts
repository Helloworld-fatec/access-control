import { prisma } from "../config/prisma.js";
import { AppError } from "../middlewares/error.middleware.js";
import { drawPokemonId, getPokemon } from "./pokemon-catalog.service.js";
import { paginate } from "../models/pagination.model.js";
import { lockVisit } from "./visits.service.js";

export function startVisitPokemonDraw(visitId: string) {
  return prisma.$transaction(async (tx) => {
    const visit = await lockVisit(tx, visitId);
    if (!visit) throw new AppError(404, "Visita não encontrada", "VISIT_NOT_FOUND");
    if (visit.exitedAt || !visit.userId) {
      throw new AppError(409, "A visita não está aberta para sorteio", "VISIT_NOT_OPEN");
    }

    const where = { visitId: visit.id };
    const existing = await tx.visitPokemonDraw.findUnique({ where });
    if (existing) return existing;
    return tx.visitPokemonDraw.create({ data: { ...where, pokemonId: drawPokemonId() } });
  });
}

export async function listUserPokemon(userId: string, page: number, pageSize: number) {
  const where = { userId };
  const [items, total] = await prisma.$transaction([
    prisma.userPokemon.findMany({
      where,
      orderBy: [{ claimedAt: "desc" }, { visitId: "desc" }],
      skip: (page - 1) * pageSize,
      take: pageSize,
      select: { visitId: true, pokemonId: true, claimedAt: true },
    }),
    prisma.userPokemon.count({ where }),
  ], { isolationLevel: "RepeatableRead" });
  const pokemon = await Promise.all(items.map(async ({ pokemonId, ...claim }) => ({
    ...claim, pokemon: await getPokemon(pokemonId),
  })));
  return paginate(pokemon, total, page, pageSize);
}
