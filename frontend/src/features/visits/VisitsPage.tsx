import { useState } from "react";
import { Link } from "react-router-dom";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "../../shared/api";
import { formatDateTime, locationLabel } from "../../shared/format";
import { useLocationOptions } from "../../shared/lookups";
import { useToast } from "../../shared/toast";
import type { Paginated, PokemonDraw, Visit, VisitStatus } from "../../shared/types";
import { Badge, ConfirmDialog, PageHeader, Pagination, QueryState } from "../../shared/ui";
import PokemonCheckoutDialog from "./PokemonCheckoutDialog";

const doorLabels = {
  PENDING: ["warn", "Aguardando porta"],
  CONFIRMED: ["ok", "Abertura confirmada"],
  FAILED: ["bad", "Falha na abertura"],
  EXPIRED: ["bad", "Comando expirado"],
} as const;

export default function VisitsPage() {
  const queryClient = useQueryClient();
  const toast = useToast();
  const locations = useLocationOptions();
  const [status, setStatus] = useState<VisitStatus>("INSIDE");
  const [search, setSearch] = useState("");
  const [locationId, setLocationId] = useState("");
  const [page, setPage] = useState(1);
  const [selection, setSelection] = useState<{ visit: Visit; kind: "simple" | "pokemon" } | null>(null);

  const filters = { search: search.trim(), locationId, pageSize: 20 };
  const insideQuery = { ...filters, status: "INSIDE", page: status === "INSIDE" ? page : 1 };
  const exitedQuery = { ...filters, status: "EXITED", page: status === "EXITED" ? page : 1 };
  const inside = useQuery({
    queryKey: ["visits", insideQuery],
    queryFn: () => api<Paginated<Visit>>("/visits", { query: insideQuery }),
    refetchInterval: 5000,
  });
  const exited = useQuery({
    queryKey: ["visits", exitedQuery],
    queryFn: () => api<Paginated<Visit>>("/visits", { query: exitedQuery }),
    refetchInterval: (query) => query.state.data?.data.some((visit) => visit.doorCommand?.status === "PENDING") ? 1000 : 5000,
  });
  const current = status === "INSIDE" ? inside : exited;

  const refreshAfterCheckout = (visit: Visit) => {
    setSelection(null);
    setStatus("EXITED");
    setPage(1);
    void queryClient.invalidateQueries({ queryKey: ["visits"] });
    if (visit.user) void queryClient.invalidateQueries({ queryKey: ["user-pokemon", visit.user.id] });
    toast(visit.checkoutType === "POKEMON" ? "Saída registrada e Pokémon salvo." : "Saída registrada.");
  };
  const simple = useMutation({
    mutationFn: (id: string) => api<Visit>(`/visits/${id}/checkout`, { method: "POST" }),
    onSuccess: refreshAfterCheckout,
  });
  const draw = useMutation({
    mutationFn: (id: string) => api<PokemonDraw>(`/visits/${id}/pokemon/draw`, { method: "POST" }),
  });
  const claim = useMutation({
    mutationFn: (id: string) => api<Visit>(`/visits/${id}/pokemon/claim`, { method: "POST" }),
    onSuccess: refreshAfterCheckout,
  });

  const insideTab = status === "INSIDE";
  return (
    <>
      <PageHeader title="Dentro e saídas">
        <button className="btn" onClick={() => { void inside.refetch(); void exited.refetch(); }}>Atualizar</button>
      </PageHeader>
      <div className="row visit-switch" role="group" aria-label="Situação das visitas">
        {([["INSIDE", "Dentro", inside.data?.total], ["EXITED", "Já saíram", exited.data?.total]] as const).map(([id, label, count]) => (
          <button key={id} className={`btn${status === id ? " btn-primary" : ""}`} aria-pressed={status === id}
            onClick={() => { if (status !== id) { setStatus(id); setPage(1); } }}>
            {label} <span className="nums">({count ?? "—"})</span>
          </button>
        ))}
      </div>
      <div className="filters">
        <label className="field">
          <span className="field-label">Buscar por nome</span>
          <input type="search" value={search} maxLength={120} onChange={(event) => { setSearch(event.target.value); setPage(1); }} />
        </label>
        <label className="field">
          <span className="field-label">Local</span>
          <select value={locationId} onChange={(event) => { setLocationId(event.target.value); setPage(1); }}>
            <option value="">Todos</option>
            {locations.data?.data.map((location) => <option key={location.id} value={location.id}>{locationLabel(location)}</option>)}
          </select>
        </label>
      </div>
      <QueryState isLoading={current.isLoading} error={current.error} empty={!current.data?.data.length}
        emptyText={insideTab ? "Nenhuma visita aberta com esses filtros." : "Nenhuma saída registrada com esses filtros."}
        onRetry={() => current.refetch()}>
        {current.data && (
          <>
            <div className="table-wrap">
              <table>
                <thead><tr><th>Usuário</th><th>Local</th><th>Entrada</th>
                  {insideTab ? <th>Checkout</th> : <><th>Saída</th><th>Tipo</th><th>Pokémon</th><th>Porta</th></>}
                </tr></thead>
                <tbody>
                  {current.data.data.map((visit) => {
                    const door = visit.doorCommand ? doorLabels[visit.doorCommand.status] : null;
                    return (
                      <tr key={visit.id}>
                        <td>{visit.user ? <Link to={`/usuarios/${visit.user.id}`}>{visit.user.name}</Link> : "Usuário removido"}</td>
                        <td>{locationLabel(visit.location)}</td>
                        <td className="nums">{formatDateTime(visit.enteredAt)}</td>
                        {insideTab ? <td className="row-actions">
                          <button className="btn btn-sm" onClick={() => { simple.reset(); setSelection({ visit, kind: "simple" }); }}>
                            Registrar saída
                          </button>
                          <button className="btn btn-primary btn-sm" onClick={() => {
                            claim.reset();
                            setSelection({ visit, kind: "pokemon" });
                            draw.mutate(visit.id);
                          }}>Sortear Pokémon</button>
                        </td> : <>
                          <td className="nums">{visit.exitedAt ? formatDateTime(visit.exitedAt) : "—"}</td>
                          <td>{visit.checkoutType === "POKEMON" ? "Com Pokémon" : "Simples"}</td>
                          <td>{visit.pokemon && visit.user
                            ? <Link to={`/usuarios/${visit.user.id}/pokemon/${visit.pokemon.pokemonId}`}>#{visit.pokemon.pokemonId}</Link>
                            : "—"}</td>
                          <td>{door ? <Badge tone={door[0]}>{door[1]}</Badge> : "—"}</td>
                        </>}
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
            <Pagination page={current.data.page} totalPages={current.data.totalPages} total={current.data.total} onPage={setPage} />
          </>
        )}
      </QueryState>
      {current.data && current.data.data.length === 0 && page > 1 && (
        <Pagination page={page} totalPages={current.data.totalPages} total={current.data.total} onPage={setPage} />
      )}
      {selection?.kind === "simple" && (
        <ConfirmDialog title="Registrar saída" message={`Registrar a saída de ${selection.visit.user?.name ?? "usuário"}? A porta permanece como está.`}
          confirmLabel="Confirmar saída" busy={simple.isPending} error={simple.error}
          onConfirm={() => simple.mutate(selection.visit.id)} onCancel={() => setSelection(null)} />
      )}
      {selection?.kind === "pokemon" && (
        <PokemonCheckoutDialog visit={selection.visit} draw={draw.data} drawing={draw.isPending} drawError={draw.error}
          claiming={claim.isPending} claimError={claim.error} onClose={() => setSelection(null)}
          onRetry={() => draw.mutate(selection.visit.id)} onClaim={() => claim.mutate(selection.visit.id)} />
      )}
    </>
  );
}
