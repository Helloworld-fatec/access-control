import { useQueries, useQuery } from "@tanstack/react-query";
import { api, ApiError } from "../../shared/api";
import type { Paginated, Terminal, TerminalStatus } from "../../shared/types";
import { locationLabel, timeAgo } from "../../shared/format";
import { Badge, QueryState } from "../../shared/ui";

const LOCK_LABEL = { LOCKED: "Trancada", UNLOCKED: "Destrancada" } as const;

function whyUnavailable(e: unknown) {
  if (e instanceof ApiError && (e.status === 401 || e.status === 403)) {
    return "O servidor só informa o status ao próprio terminal (exige a chave do terminal).";
  }
  return e instanceof Error ? e.message : "Status indisponível.";
}

/** Um cartão por terminal, atualizado por polling (US-16). */
export default function TerminalMonitor({ interval }: { interval: number | false }) {
  const list = useQuery({
    queryKey: ["dashboard", "terminals"],
    queryFn: () => api<Paginated<Terminal>>("/terminals", { query: { pageSize: 100 } }),
    refetchInterval: interval === false ? false : 30_000,
  });
  const terminals = list.data?.data ?? [];
  const statuses = useQueries({
    queries: terminals.map((t) => ({
      queryKey: ["dashboard", "terminal-status", t.id],
      queryFn: () => api<TerminalStatus>(`/terminals/${t.id}/status`),
      refetchInterval: interval,
      retry: false,
    })),
  });

  return (
    <QueryState isLoading={list.isLoading} error={list.error} empty={terminals.length === 0} emptyText="Nenhum terminal cadastrado." onRetry={() => list.refetch()}>
      <div className="terminal-grid">
        {terminals.map((t, i) => {
          const st = statuses[i];
          const s = st?.data;
          return (
            <article key={t.id} className="panel terminal-card" aria-label={`Terminal ${t.name}`}>
              <h3>{t.name}</h3>
              <p className="muted">{locationLabel(t.location)}</p>
              {st?.isError ? (
                <p className="field-error" role="alert">Status indisponível. {whyUnavailable(st.error)}</p>
              ) : !s ? (
                <p className="muted">Carregando status…</p>
              ) : (
                <dl className="facts compact">
                  <div><dt>Conexão</dt><dd><Badge tone={s.online ? "ok" : "muted"}>{s.online ? "Online" : "Offline"}</Badge></dd></div>
                  <div><dt>Presença</dt><dd><Badge tone={s.presenceActive ? "warn" : "muted"}>{s.presenceActive ? "Pessoa detectada" : "Ninguém"}</Badge></dd></div>
                  <div><dt>Última presença</dt><dd>{timeAgo(s.lastPresenceAt)}</dd></div>
                  <div><dt>Trava</dt><dd>{s.lock ? LOCK_LABEL[s.lock] : "—"}</dd></div>
                </dl>
              )}
            </article>
          );
        })}
      </div>
    </QueryState>
  );
}
