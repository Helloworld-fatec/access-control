import { useState } from "react";
import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { api } from "../../shared/api";
import { useTerminalOptions, useUserOptions } from "../../shared/lookups";
import type { AccessLog, AccessResult, Method, Paginated } from "../../shared/types";
import { formatDateTime, METHOD_LABEL, REASON_LABEL } from "../../shared/format";
import { Badge, PageHeader, Pagination, QueryState } from "../../shared/ui";

export default function AccessLogsPage() {
  const users = useUserOptions();
  const terminals = useTerminalOptions();
  const [page, setPage] = useState(1);
  const [f, setF] = useState({ userId: "", terminalId: "", method: "" as "" | Method, result: "" as "" | AccessResult, from: "", to: "" });
  const set = (patch: Partial<typeof f>) => {
    setF((p) => ({ ...p, ...patch }));
    setPage(1);
  };
  const invalidRange = Boolean(f.from && f.to && f.to < f.from);

  // Filtros e paginação são feitos no servidor (US-13).
  const q = useQuery({
    queryKey: ["access-logs", { page, ...f }],
    queryFn: () => api<Paginated<AccessLog>>("/access-logs", { query: { page, pageSize: 25, ...f } }),
    placeholderData: keepPreviousData,
    enabled: !invalidRange,
  });

  return (
    <>
      <PageHeader title="Histórico de acessos" />
      <div className="filters">
        <label className="field"><span className="field-label">De</span><input type="date" value={f.from} onChange={(e) => set({ from: e.target.value })} /></label>
        <label className="field"><span className="field-label">Até</span><input type="date" value={f.to} onChange={(e) => set({ to: e.target.value })} /></label>
        <label className="field"><span className="field-label">Pessoa</span>
          <select value={f.userId} onChange={(e) => set({ userId: e.target.value })}>
            <option value="">Todas</option>
            {users.data?.data.map((u) => <option key={u.id} value={u.id}>{u.name}</option>)}
          </select>
        </label>
        <label className="field"><span className="field-label">Terminal</span>
          <select value={f.terminalId} onChange={(e) => set({ terminalId: e.target.value })}>
            <option value="">Todos</option>
            {terminals.data?.data.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}
          </select>
        </label>
        <label className="field"><span className="field-label">Método</span>
          <select value={f.method} onChange={(e) => set({ method: e.target.value as "" | Method })}>
            <option value="">Todos</option>
            {(Object.keys(METHOD_LABEL) as Method[]).map((m) => <option key={m} value={m}>{METHOD_LABEL[m]}</option>)}
          </select>
        </label>
        <label className="field"><span className="field-label">Resultado</span>
          <select value={f.result} onChange={(e) => set({ result: e.target.value as "" | AccessResult })}>
            <option value="">Todos</option>
            <option value="GRANTED">Liberado</option>
            <option value="DENIED">Negado</option>
          </select>
        </label>
      </div>
      {invalidRange && <p className="form-error" role="alert">A data final deve ser igual ou posterior à inicial.</p>}

      <QueryState isLoading={q.isLoading && !invalidRange} error={q.error} empty={!invalidRange && q.data?.data.length === 0} emptyText="Nenhuma tentativa de acesso encontrada com esses filtros." onRetry={() => q.refetch()}>
        {q.data && !invalidRange && (
          <>
            <div className="table-wrap">
              <table>
                <thead><tr><th>Data e hora</th><th>Pessoa</th><th>Terminal</th><th>Método</th><th>Resultado</th><th>Motivo</th></tr></thead>
                <tbody>
                  {q.data.data.map((l) => (
                    <tr key={l.id}>
                      <td className="nums">{formatDateTime(l.createdAt)}</td>
                      <td>{l.user?.name ?? (l.nfcUid ? <>Tag desconhecida <code>{l.nfcUid}</code></> : "Não identificada")}</td>
                      <td>{l.terminal?.name ?? "—"}</td>
                      <td>{METHOD_LABEL[l.method]}</td>
                      <td><Badge tone={l.result === "GRANTED" ? "ok" : "bad"}>{l.result === "GRANTED" ? "Liberado" : "Negado"}</Badge></td>
                      <td>{l.reason ? REASON_LABEL[l.reason] ?? l.reason : "—"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <Pagination page={q.data.page} totalPages={q.data.totalPages} total={q.data.total} onPage={setPage} />
          </>
        )}
      </QueryState>
    </>
  );
}
