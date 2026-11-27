import { apiUrl } from "../../shared/api";
import type { Pokemon } from "../../shared/types";

export const pokemonImageUrl = (path: string) => apiUrl(path.replace(/^\/api(?=\/)/, ""));

export default function PokemonImage({ pokemon }: { pokemon: Pokemon }) {
  return pokemon.imagem_url ? (
    <img className="pokemon-image" src={pokemonImageUrl(pokemon.imagem_url)}
      alt={pokemon.nome} width={220} height={220} />
  ) : <div className="pokemon-image pokemon-image-placeholder" aria-label="Imagem indisponível">#{pokemon.id}</div>;
}
