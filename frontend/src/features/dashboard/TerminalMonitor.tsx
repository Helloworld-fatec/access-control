import { useQuery } from "@tanstack/react-query";
import { api } from "../../shared/api";
import type { Paginated, Terminal, TerminalStatus } from "../../shared/types";
import { locationLabel, timeAgo } from "../../shared/format";
import { Badge, QueryState } from "../../shared/ui";

const LOCK_LABEL = { LOCKED: "Trancada", UNLOCKED: "Destrancada" } as const;

/** Um cartão por terminal, atualizado por polling (US-16). */
export default function TerminalMonitor({ interval }: { interval: number | false }) {
  const list = useQuery({
    queryKey: ["dashboard", "terminals"],
    queryFn: () => api<Paginated<Terminal>>("/terminals", { query: { pageSize: 100 } }),
    refetchInterval: interval === false ? false : 30_000,
  });
  // Uma única chamada traz a situação de todos os terminais (rota do administrador).
  const status = useQuery({
    queryKey: ["dashboard", "terminal-status"],
    queryFn: () => api<{ data: TerminalStatus[] }>("/terminals/status"),
    refetchInterval: interval,
  });
  const terminals = list.data?.data ?? [];
  const byId = new Map((status.data?.data ?? []).map((s) => [s.id, s]));

  return (
    <QueryState isLoading={list.isLoading} error={list.error} empty={terminals.length === 0} emptyText="Nenhum terminal cadastrado." onRetry={() => list.refetch()}>
      <div className="terminal-grid">
        {terminals.map((t) => {
          const s = byId.get(t.id);
          return (
            <article key={t.id} className="panel terminal-card" aria-label={`Terminal ${t.name}`}>
              <h3>{t.name}</h3>
              <p className="muted">{locationLabel(t.location)}</p>
              {status.isError ? (
                <p className="field-error" role="alert">Status indisponível. {status.error instanceof Error ? status.error.message : ""}</p>
              ) : !s ? (
                <p className="muted">Carregando status…</p>
              ) : (
                <dl className="facts compact">
                  <div><dt>Conexão</dt><dd><Badge tone={s.online ? "ok" : "muted"}>{s.online ? "Online" : "Offline"}</Badge></dd></div>
                  <div><dt>Presença</dt><dd><Badge tone={s.presenceActive ? "warn" : "muted"}>{s.presenceActive ? "Pessoa detectada" : "Ninguém"}</Badge></dd></div>
                  <div><dt>Última presença</dt><dd>{timeAgo(s.lastPresenceAt)}</dd></div>
                  <div><dt>Visto pela última vez</dt><dd>{timeAgo(s.lastSeenAt)}</dd></div>
                  {s.lock && <div><dt>Trava</dt><dd>{LOCK_LABEL[s.lock]}</dd></div>}
                </dl>
              )}
            </article>
          );
        })}
      </div>
    </QueryState>
  );
}
