import { useState, type ReactNode } from "react";
import { useQuery } from "@tanstack/react-query";
import { api, ApiError } from "../../shared/api";
import type { DashboardSummary, HourBucket, Method } from "../../shared/types";
import { METHOD_LABEL, REASON_LABEL, todayInSaoPaulo } from "../../shared/format";
import { PageHeader, QueryState } from "../../shared/ui";
import HoursChart from "./HoursChart";
import RecentEvents from "./RecentEvents";
import TerminalMonitor from "./TerminalMonitor";

const POLL_MS = 5000;
const pct = (n: number) => `${(n * 100).toFixed(1).replace(".", ",")}%`;

/** Enquanto o backend não tem /dashboard/*, explica o que está faltando em vez de mostrar um erro genérico. */
function dashboardError(e: unknown): unknown {
  if (e instanceof ApiError && e.status === 404) {
    return new Error("Este indicador ainda não existe no backend. Para ver dados de exemplo, rode o front com: npm run dev:mock");
  }
  return e;
}

function Stat({ label, value, hint }: { label: string; value: ReactNode; hint?: string }) {
  return (
    <div className="panel stat">
      <div className="stat-value nums">{value}</div>
      <div className="stat-label">{label}</div>
      {hint && <div className="field-hint">{hint}</div>}
    </div>
  );
}

function Bars({ rows, tone }: { rows: { label: string; count: number }[]; tone: "teal" | "red" }) {
  const max = Math.max(...rows.map((r) => r.count), 1);
  return (
    <ul className="bars">
      {rows.map((r) => (
        <li key={r.label}>
          <span className="bar-label">{r.label}</span>
          <span className="bar-track" aria-hidden="true"><span className={`bar-fill bar-${tone}`} style={{ width: `${(r.count / max) * 100}%` }} /></span>
          <span className="bar-count nums">{r.count}</span>
        </li>
      ))}
    </ul>
  );
}

export default function DashboardPage() {
  const today = todayInSaoPaulo();
  const [date, setDate] = useState(today);
  const [paused, setPaused] = useState(false);
  const interval = paused ? false : POLL_MS;
  const daily = paused || date !== today ? false : 30_000;

  const summary = useQuery({
    queryKey: ["dashboard", "summary", date],
    queryFn: () => api<DashboardSummary>("/dashboard/summary", { query: { date } }),
    refetchInterval: daily,
    retry: false,
  });
  const hours = useQuery({
    queryKey: ["dashboard", "hours", date],
    queryFn: () => api<HourBucket[]>("/dashboard/accesses-by-hour", { query: { date } }),
    refetchInterval: daily,
    retry: false,
  });
  const s = summary.data;

  return (
    <>
      <PageHeader title="Painel">
        <label className="field inline">
          <span className="field-label">Dia</span>
          <input type="date" value={date} max={today} onChange={(e) => e.target.value && setDate(e.target.value)} />
        </label>
        <label className="check">
          <input type="checkbox" checked={paused} onChange={(e) => setPaused(e.target.checked)} /> Pausar atualização automática
        </label>
      </PageHeader>

      <section aria-labelledby="h-resumo" className="block">
        <h2 id="h-resumo">Resumo do dia</h2>
        <QueryState isLoading={summary.isLoading} error={dashboardError(summary.error)} empty={false} emptyText="" onRetry={() => summary.refetch()}>
          {s && (
            <>
              <div className="stats">
                <Stat label="Acessos liberados" value={s.granted} />
                <Stat label="Acessos negados" value={s.denied} />
                <Stat label="Taxa de negação" value={pct(s.denialRate)} hint={`${s.granted + s.denied} tentativas no dia`} />
              </div>
              <div className="stats">
                <Stat label="Autorizações ativas" value={s.authorizations.active} />
                <Stat label="Expiram em 7 dias" value={s.authorizations.expiringSoon} />
                <Stat label="Autorizações canceladas" value={s.authorizations.canceled} />
              </div>
              <div className="grid-2 block">
                <section className="panel" aria-labelledby="h-metodo">
                  <h3 id="h-metodo">Acessos por método</h3>
                  <Bars tone="teal" rows={(Object.keys(METHOD_LABEL) as Method[]).map((m) => ({ label: METHOD_LABEL[m], count: s.byMethod[m] }))} />
                </section>
                <section className="panel" aria-labelledby="h-motivos">
                  <h3 id="h-motivos">Principais motivos de negação</h3>
                  {s.topDenialReasons.length === 0 ? (
                    <p className="muted">Nenhum acesso negado neste dia.</p>
                  ) : (
                    <Bars tone="red" rows={s.topDenialReasons.map((r) => ({ label: REASON_LABEL[r.reason] ?? r.reason, count: r.count }))} />
                  )}
                </section>
              </div>
            </>
          )}
        </QueryState>
      </section>

      <section aria-labelledby="h-hora" className="block">
        <h2 id="h-hora">Acessos por hora</h2>
        <div className="panel">
          <QueryState isLoading={hours.isLoading} error={dashboardError(hours.error)} empty={false} emptyText="" onRetry={() => hours.refetch()}>
            {hours.data && <HoursChart data={hours.data} />}
          </QueryState>
        </div>
      </section>

      <section aria-labelledby="h-term" className="block">
        <h2 id="h-term">Terminais</h2>
        <p className="muted live-note">{paused ? "Atualização automática pausada." : "Atualiza a cada 5 segundos."}</p>
        <TerminalMonitor interval={interval} />
      </section>

      <section aria-labelledby="h-ult" className="block">
        <h2 id="h-ult">Últimos acessos</h2>
        <RecentEvents interval={interval} />
      </section>
    </>
  );
}
