import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Link } from "react-router-dom";
import { api } from "../../shared/api";
import { formatDateTime } from "../../shared/format";
import type { Paginated, PokemonClaim } from "../../shared/types";
import { Badge, Pagination, QueryState } from "../../shared/ui";

export default function UserPokemonCollection({ userId }: { userId: string }) {
  const [page, setPage] = useState(1);
  const query = useQuery({
    queryKey: ["user-pokemon", userId, page],
    queryFn: () => api<Paginated<PokemonClaim>>(`/users/${userId}/pokemon`, { query: { page, pageSize: 10 } }),
  });
  return (
    <section className="panel">
      <div className="row spread">
        <h2>Pokémon obtidos</h2>
        {query.data && <Badge tone="muted">{query.data.total}</Badge>}
      </div>
      <QueryState isLoading={query.isLoading} error={query.error} empty={!query.data?.data.length}
        emptyText="Este usuário ainda não tem Pokémon." onRetry={() => query.refetch()}>
        {query.data && (
          <>
            <ul className="list">
              {query.data.data.map(({ visitId, claimedAt, pokemon }) => (
                <li key={visitId}>
                  <Link to={`/usuarios/${userId}/pokemon/${pokemon.id}`}><strong>{pokemon.nome}</strong> <span className="nums">#{pokemon.id}</span></Link>
                  <time dateTime={claimedAt} className="muted nums">{formatDateTime(claimedAt)}</time>
                </li>
              ))}
            </ul>
            {query.data.totalPages > 1 && <Pagination page={page} totalPages={query.data.totalPages} total={query.data.total} onPage={setPage} />}
          </>
        )}
      </QueryState>
    </section>
  );
}
