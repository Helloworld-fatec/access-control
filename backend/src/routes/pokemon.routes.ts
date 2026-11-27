import { Router } from "express";
import { asyncHandler } from "../middlewares/error.middleware.js";
import { getPokemon, pokemonImagePath } from "../services/pokemon-catalog.service.js";

export const pokemonRoutes = Router();

pokemonRoutes.get("/:id/image", (req, res) => {
  res.sendFile(pokemonImagePath(req.params.id), { maxAge: "1h" });
});

pokemonRoutes.get("/:id", asyncHandler(async (req, res) => {
  res.json(await getPokemon(req.params.id));
}));
