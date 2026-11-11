import { useState } from "react";
import { Link, useParams } from "react-router-dom";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "../../shared/api";
import type { Authorization } from "../../shared/types";
import { formatDateOnly, formatDateTime, locationLabel, STATUS_LABEL } from "../../shared/format";
import { useToast } from "../../shared/toast";
import { Badge, ConfirmDialog, PageHeader, QueryState } from "../../shared/ui";

export default function AuthorizationDetailPage() {
  const { id } = useParams();
  const qc = useQueryClient();
  const toast = useToast();
  const [confirming, setConfirming] = useState(false);

  const q = useQuery({ queryKey: ["authorization", id], queryFn: () => api<Authorization>(`/authorizations/${id}`) });
  const cancel = useMutation({
    mutationFn: () => api(`/authorizations/${id}/cancel`, { method: "PATCH", body: {} }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["authorization", id] });
      qc.invalidateQueries({ queryKey: ["authorizations"] });
      toast("Autorização cancelada.");
      setConfirming(false);
    },
  });

  const a = q.data;
  return (
    <>
      <PageHeader title="Autorização">
        <Link className="btn" to="/autorizacoes">Voltar à lista</Link>
        {a?.status === "ACTIVE" && (
          <button className="btn btn-danger" onClick={() => setConfirming(true)}>Cancelar autorização</button>
        )}
      </PageHeader>

      <QueryState isLoading={q.isLoading} error={q.error} empty={!a} emptyText="Autorização não encontrada." onRetry={() => q.refetch()}>
        {a && (
          <section className="panel">
            <dl className="facts">
              <div><dt>Pessoa</dt><dd>{a.user ? <Link to={`/usuarios/${a.user.id}`}>{a.user.name}</Link> : "—"}</dd></div>
              <div><dt>Local</dt><dd>{locationLabel(a.location)}</dd></div>
              <div><dt>Período</dt><dd>{formatDateOnly(a.startDate)} a {formatDateOnly(a.endDate)}</dd></div>
              <div><dt>Horário</dt><dd>{a.startTime} às {a.endTime}</dd></div>
              <div><dt>Usos</dt><dd>{a.maxUses === null ? `Ilimitado (${a.usedCount} usados)` : `${a.usedCount} de ${a.maxUses} usados, restam ${a.remainingUses}`}</dd></div>
              <div><dt>Situação</dt><dd><Badge tone={a.status === "ACTIVE" ? "ok" : a.status === "EXPIRED" ? "warn" : "muted"}>{STATUS_LABEL[a.status]}</Badge></dd></div>
              <div><dt>Criada em</dt><dd>{formatDateTime(a.createdAt ?? null)}</dd></div>
              {a.status === "CANCELED" && <div><dt>Cancelada em</dt><dd>{formatDateTime(a.canceledAt ?? null)}</dd></div>}
            </dl>
          </section>
        )}
      </QueryState>

      {confirming && a && (
        <ConfirmDialog
          title="Cancelar autorização?"
          message={`${a.user?.name ?? "A pessoa"} perderá o acesso a ${locationLabel(a.location)}. Essa ação não pode ser desfeita; o registro continua visível como cancelado.`}
          confirmLabel="Cancelar autorização"
          danger
          busy={cancel.isPending}
          error={cancel.error}
          onConfirm={() => cancel.mutate()}
          onCancel={() => { cancel.reset(); setConfirming(false); }}
        />
      )}
    </>
  );
}
