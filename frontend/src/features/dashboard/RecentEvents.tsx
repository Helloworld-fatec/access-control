import { useQuery } from "@tanstack/react-query";
import { api } from "../../shared/api";
import type { AccessLog, Paginated } from "../../shared/types";
import { formatDateTime, METHOD_LABEL, REASON_LABEL } from "../../shared/format";
import { Badge, QueryState } from "../../shared/ui";

/** Últimos acessos, atualizados por polling (US-16). */
export default function RecentEvents({ interval }: { interval: number | false }) {
  const q = useQuery({
    queryKey: ["dashboard", "recent-events"],
    queryFn: () => api<Paginated<AccessLog>>("/access-logs", { query: { pageSize: 10 } }),
    refetchInterval: interval,
  });

  return (
    <QueryState isLoading={q.isLoading} error={q.error} empty={q.data?.data.length === 0} emptyText="Nenhum acesso registrado ainda." onRetry={() => q.refetch()}>
      <div className="table-wrap">
        <table>
          <thead><tr><th>Data e hora</th><th>Pessoa</th><th>Terminal</th><th>Método</th><th>Resultado</th><th>Motivo</th></tr></thead>
          <tbody>
            {q.data?.data.map((l) => (
              <tr key={l.id}>
                <td className="nums">{formatDateTime(l.createdAt)}</td>
                <td>{l.user?.name ?? (l.nfcUid ? "Tag desconhecida" : "Não identificada")}</td>
                <td>{l.terminal?.name ?? "—"}</td>
                <td>{METHOD_LABEL[l.method]}</td>
                <td><Badge tone={l.result === "GRANTED" ? "ok" : "bad"}>{l.result === "GRANTED" ? "Liberado" : "Negado"}</Badge></td>
                <td>{l.reason ? REASON_LABEL[l.reason] ?? l.reason : "—"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </QueryState>
  );
}
