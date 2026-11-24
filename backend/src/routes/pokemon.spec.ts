import { stat } from "node:fs/promises";
import request from "supertest";
import { expect, it } from "vitest";
import { app } from "../index.js";
import { getPokemon, pokemonIds, pokemonImagePath } from "../services/pokemon-catalog.service.js";

it("valida os 79 registros elegíveis e as imagens locais", async () => {
  expect(pokemonIds).toHaveLength(79);
  expect(new Set(pokemonIds).size).toBe(79);
  await Promise.all(pokemonIds.map(async (id) => {
    const [pokemon, image] = await Promise.all([getPokemon(id), stat(pokemonImagePath(id))]);
    expect(pokemon.id).toBe(id);
    expect(image.isFile() && image.size > 0).toBe(true);
  }));
});

it("serve dados selecionados e PNG local preservando zeros à esquerda", async () => {
  const api = request(app);
  const detail = await api.get("/api/pokemon/001");
  expect(detail.status).toBe(200);
  expect(detail.body).toEqual({
    id: "001", numero: 1, nome: "Bulbasaur", altura_m: 0.7, peso_kg: 6.9,
    stats: { hp: 45, attack: 49, defense: 49, "special-attack": 65, "special-defense": 65, speed: 45 },
    imagem_url: "/api/pokemon/001/image",
  });
  const image = await api.get(detail.body.imagem_url);
  expect(image.status).toBe(200);
  expect(image.headers["content-type"]).toBe("image/png");
  expect(image.body.subarray(0, 8)).toEqual(Buffer.from("89504e470d0a1a0a", "hex"));
});

it.each(["/api/pokemon/002", "/api/pokemon/1/image", "/api/pokemon/%2e%2e%2f001/image"])(
  "bloqueia ID fora da lista em %s",
  async (path) => {
    const response = await request(app).get(path);
    expect(response.status).toBe(404);
    expect(response.body.error.code).toBe("POKEMON_NOT_FOUND");
  },
);
