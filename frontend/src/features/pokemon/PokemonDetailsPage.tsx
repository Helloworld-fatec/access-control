import { useQuery } from "@tanstack/react-query";
import { Link, useParams } from "react-router-dom";
import { api } from "../../shared/api";
import type { Pokemon } from "../../shared/types";
import { PageHeader, QueryState } from "../../shared/ui";
import PokemonImage from "./PokemonImage";

const number = new Intl.NumberFormat("pt-BR");
const stats = [
  ["hp", "PS"], ["attack", "Ataque"], ["defense", "Defesa"],
  ["special-attack", "Ataque especial"], ["special-defense", "Defesa especial"], ["speed", "Velocidade"],
] as const;

export default function PokemonDetailsPage() {
  const { id, pokemonId } = useParams();
  const query = useQuery({
    queryKey: ["pokemon", pokemonId],
    queryFn: () => api<Pokemon>(`/pokemon/${encodeURIComponent(pokemonId!)}`, { authenticated: false }),
    enabled: !!pokemonId,
  });
  const pokemon = query.data;
  return (
    <>
      <PageHeader title={pokemon?.nome ?? "Pokémon"}>
        <Link to={`/usuarios/${id}`} className="btn">Voltar ao perfil</Link>
      </PageHeader>
      <QueryState isLoading={query.isLoading} error={query.error} empty={!pokemon}
        emptyText="Pokémon não encontrado." onRetry={() => query.refetch()}>
        {pokemon && (
          <div className="stack">
            <section className="panel profile pokemon-profile">
              <PokemonImage pokemon={pokemon} />
              <dl className="facts compact">
                <div><dt>Número</dt><dd className="nums">#{pokemon.id}</dd></div>
                <div><dt>Altura</dt><dd>{number.format(pokemon.altura_m)} m</dd></div>
                <div><dt>Peso</dt><dd>{number.format(pokemon.peso_kg)} kg</dd></div>
              </dl>
            </section>
            <section className="panel">
              <h2>Estatísticas</h2>
              <dl className="facts">
                {stats.map(([key, label]) => <div key={key}><dt>{label}</dt><dd className="nums">{pokemon.stats[key]}</dd></div>)}
              </dl>
            </section>
          </div>
        )}
      </QueryState>
    </>
  );
}
