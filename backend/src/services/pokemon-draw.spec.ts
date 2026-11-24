import { beforeEach, expect, it, vi } from "vitest";
import { startVisitPokemonDraw } from "./pokemon-draw.service.js";
import { pokemonIds } from "./pokemon-catalog.service.js";

const { db } = vi.hoisted(() => ({
  db: {
    $queryRaw: vi.fn(),
    $transaction: vi.fn(),
    visitPokemonDraw: { findUnique: vi.fn(), create: vi.fn() },
  },
}));
vi.mock("../config/prisma.js", () => ({ prisma: db }));

const visitId = "14825695-6cdb-4e40-a33e-94045475eabb";
const visit = { id: visitId, userId: "morador", exitedAt: null };

beforeEach(() => {
  vi.resetAllMocks();
  db.$transaction.mockImplementation((run) => run(db));
  db.$queryRaw.mockResolvedValue([visit]);
});

it("seleciona um ID da lista uma vez e devolve o mesmo sorteio ao retornar", async () => {
  db.visitPokemonDraw.create.mockImplementation(async ({ data }) => {
    const draw = { ...data, drawnAt: new Date() };
    db.visitPokemonDraw.findUnique.mockResolvedValue(draw);
    return draw;
  });
  const draw = await startVisitPokemonDraw(visitId);
  expect(pokemonIds).toContain(draw.pokemonId);
  expect(draw.visitId).toBe(visitId);
  await expect(startVisitPokemonDraw(visitId)).resolves.toEqual(draw);
  expect(db.visitPokemonDraw.create).toHaveBeenCalledTimes(1);
  expect(db.$queryRaw.mock.calls[0]![0].join("")).toContain("FOR UPDATE");
});

it.each([
  { visits: [], code: "VISIT_NOT_FOUND" },
  { visits: [{ ...visit, exitedAt: new Date() }], code: "VISIT_NOT_OPEN" },
  { visits: [{ ...visit, userId: null }], code: "VISIT_NOT_OPEN" },
])("preserva visitas inválidas sem criar sorteio: $code", async ({ visits, code }) => {
  db.$queryRaw.mockResolvedValue(visits);
  await expect(startVisitPokemonDraw(visitId)).rejects.toMatchObject({ code });
  expect(db.visitPokemonDraw.create).not.toHaveBeenCalled();
});
