import { randomInt } from "node:crypto";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { z } from "zod";
import { AppError } from "../middlewares/error.middleware.js";

export const pokemonIds = [
  "001", "004", "007", "010", "013", "016", "019", "021", "023", "025",
  "027", "029", "032", "035", "037", "039", "041", "043", "046", "048",
  "050", "052", "054", "056", "058", "060", "063", "066", "069", "072",
  "074", "077", "079", "081", "083", "084", "086", "088", "090", "092",
  "095", "096", "098", "100", "102", "104", "106", "107", "108", "109",
  "111", "113", "114", "115", "116", "118", "120", "122", "123", "124",
  "125", "126", "127", "128", "129", "131", "132", "133", "137", "138",
  "140", "142", "143", "144", "145", "146", "147", "150", "151",
] as const;

const eligibleIds = new Set<string>(pokemonIds);
const dataDirectory = new URL("../../pokemon-data/", import.meta.url);
const stat = z.number().int().nonnegative();
const pokemonData = z.object({
  id: z.string(),
  numero: z.number().int().positive(),
  nome: z.string().min(1),
  altura_m: z.number().positive(),
  peso_kg: z.number().positive(),
  stats: z.object({
    hp: stat,
    attack: stat,
    defense: stat,
    "special-attack": stat,
    "special-defense": stat,
    speed: stat,
  }),
});

function requirePokemonId(id: unknown): string {
  if (typeof id !== "string" || !eligibleIds.has(id)) {
    throw new AppError(404, "Pokémon não encontrado no catálogo", "POKEMON_NOT_FOUND");
  }
  return id;
}

export function drawPokemonId(): string {
  return pokemonIds[randomInt(pokemonIds.length)]!;
}

export function pokemonImagePath(input: unknown): string {
  const id = requirePokemonId(input);
  return fileURLToPath(new URL(`pokemons_images/${id}.png`, dataDirectory));
}

export async function getPokemon(input: unknown) {
  const id = requirePokemonId(input);
  const file = new URL(`pokemon-info/${id}.json`, dataDirectory);
  const parsed = pokemonData.safeParse(JSON.parse(await readFile(file, "utf8")));
  if (!parsed.success || parsed.data.id !== id || parsed.data.numero !== Number(id)) {
    throw new Error(`Registro de Pokémon incompatível com o ID ${id}`);
  }
  return { ...parsed.data, imagem_url: `/api/pokemon/${id}/image` };
}
