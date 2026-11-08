import { useState } from "react";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "../../shared/api";
import { applyApiErrors } from "../../shared/forms";
import { useLocationOptions, useUserOptions } from "../../shared/lookups";
import { useAuth } from "../auth/AuthContext";
import type { AuthStatus, Authorization, Paginated } from "../../shared/types";
import { formatDateOnly, locationLabel, STATUS_LABEL } from "../../shared/format";
import { Badge, ConfirmDialog, Field, Modal, PageHeader, Pagination, QueryState } from "../../shared/ui";

// Mensagens específicas de validação (US-11).
const schema = z
  .object({
    userId: z.string().min(1, "Escolha a pessoa"),
    locationId: z.string().min(1, "Escolha o local"),
    startDate: z.string().min(1, "Informe a data de início"),
    endDate: z.string().min(1, "Informe a data de término"),
    startTime: z.string().min(1, "Informe o horário inicial"),
    endTime: z.string().min(1, "Informe o horário final"),
    maxUses: z.string().trim().refine((v) => v === "" || (/^\d+$/.test(v) && Number(v) > 0), "Use um número inteiro maior que zero, ou deixe em branco"),
  })
  .refine((v) => !v.startDate || !v.endDate || v.endDate >= v.startDate, { message: "A data de término deve ser igual ou posterior à de início", path: ["endDate"] })
  .refine((v) => !v.startTime || !v.endTime || v.endTime > v.startTime, { message: "O horário de término deve ser posterior ao de início", path: ["endTime"] });
type Values = z.infer<typeof schema>;
const FIELDS = ["userId", "locationId", "startDate", "endDate", "startTime", "endTime", "maxUses"];

function CreateForm({ onClose }: { onClose: () => void }) {
  const qc = useQueryClient();
  const { user: admin } = useAuth();
  const users = useUserOptions();
  const locations = useLocationOptions();
  const [formError, setFormError] = useState<string | null>(null);
  const { register, handleSubmit, setError, formState } = useForm<Values>({
    resolver: zodResolver(schema),
    defaultValues: { userId: "", locationId: "", startDate: "", endDate: "", startTime: "08:00", endTime: "18:00", maxUses: "" },
  });
  const save = useMutation({
    mutationFn: (v: Values) =>
      api("/authorizations", {
        method: "POST",
        // createdById sai daqui quando o backend passar a ler o administrador do token.
        body: { ...v, maxUses: v.maxUses ? Number(v.maxUses) : null, createdById: admin!.id },
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["authorizations"] });
      onClose();
    },
  });
  const onSubmit = handleSubmit(async (v) => {
    setFormError(null);
    try {
      await save.mutateAsync(v);
    } catch (e) {
      setFormError(applyApiErrors(e, setError, FIELDS));
    }
  });
  return (
    <Modal title="Nova autorização" onClose={onClose} wide>
      <form className="form" onSubmit={onSubmit} noValidate>
        <div className="grid-2">
          <Field label="Pessoa" error={formState.errors.userId?.message}>
            <select {...register("userId")}>
              <option value="">Escolha uma pessoa</option>
              {users.data?.data.filter((u) => u.active).map((u) => <option key={u.id} value={u.id}>{u.name}</option>)}
            </select>
          </Field>
          <Field label="Local" error={formState.errors.locationId?.message}>
            <select {...register("locationId")}>
              <option value="">Escolha um local</option>
              {locations.data?.data.map((l) => <option key={l.id} value={l.id}>{locationLabel(l)}</option>)}
            </select>
          </Field>
        </div>
        <div className="grid-2">
          <Field label="Data de início" error={formState.errors.startDate?.message}><input type="date" {...register("startDate")} /></Field>
          <Field label="Data de término" error={formState.errors.endDate?.message}><input type="date" {...register("endDate")} /></Field>
        </div>
        <div className="grid-2">
          <Field label="Horário inicial" error={formState.errors.startTime?.message}><input type="time" {...register("startTime")} /></Field>
          <Field label="Horário final" error={formState.errors.endTime?.message}><input type="time" {...register("endTime")} /></Field>
        </div>
        <Field label="Quantidade de usos" hint="Deixe em branco para usos ilimitados." error={formState.errors.maxUses?.message}>
          <input inputMode="numeric" {...register("maxUses")} />
        </Field>
        {formError && <p className="form-error" role="alert">{formError}</p>}
        <div className="actions">
          <button type="button" className="btn" onClick={onClose}>Cancelar</button>
          <button className="btn btn-primary" disabled={formState.isSubmitting}>{formState.isSubmitting ? "Salvando…" : "Criar autorização"}</button>
        </div>
      </form>
    </Modal>
  );
}

export default function AuthorizationsPage() {
  const qc = useQueryClient();
  const { user: admin } = useAuth();
  const users = useUserOptions();
  const locations = useLocationOptions();
  const [page, setPage] = useState(1);
  const [f, setF] = useState({ userId: "", locationId: "", status: "" as "" | AuthStatus, from: "", to: "" });
  const [creating, setCreating] = useState(false);
  const [canceling, setCanceling] = useState<Authorization | null>(null);

  const set = (patch: Partial<typeof f>) => {
    setF((p) => ({ ...p, ...patch }));
    setPage(1);
  };
  const invalidRange = Boolean(f.from && f.to && f.to < f.from);

  const q = useQuery({
    queryKey: ["authorizations", { page, ...f }],
    queryFn: () => api<Paginated<Authorization>>("/authorizations", { query: { page, pageSize: 20, ...f } }),
    placeholderData: keepPreviousData,
    enabled: !invalidRange,
  });
  const cancel = useMutation({
    mutationFn: (id: string) => api(`/authorizations/${id}/cancel`, { method: "PATCH", body: { canceledById: admin!.id } }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["authorizations"] });
      setCanceling(null);
    },
  });

  return (
    <>
      <PageHeader title="Autorizações">
        <button className="btn btn-primary" onClick={() => setCreating(true)}>Nova autorização</button>
      </PageHeader>

      <div className="filters">
        <label className="field"><span className="field-label">Pessoa</span>
          <select value={f.userId} onChange={(e) => set({ userId: e.target.value })}>
            <option value="">Todas</option>
            {users.data?.data.map((u) => <option key={u.id} value={u.id}>{u.name}</option>)}
          </select>
        </label>
        <label className="field"><span className="field-label">Local</span>
          <select value={f.locationId} onChange={(e) => set({ locationId: e.target.value })}>
            <option value="">Todos</option>
            {locations.data?.data.map((l) => <option key={l.id} value={l.id}>{locationLabel(l)}</option>)}
          </select>
        </label>
        <label className="field"><span className="field-label">Situação</span>
          <select value={f.status} onChange={(e) => set({ status: e.target.value as "" | AuthStatus })}>
            <option value="">Todas</option>
            {(Object.keys(STATUS_LABEL) as AuthStatus[]).map((s) => <option key={s} value={s}>{STATUS_LABEL[s]}</option>)}
          </select>
        </label>
        <label className="field"><span className="field-label">Período de</span><input type="date" value={f.from} onChange={(e) => set({ from: e.target.value })} /></label>
        <label className="field"><span className="field-label">até</span><input type="date" value={f.to} onChange={(e) => set({ to: e.target.value })} /></label>
      </div>
      {invalidRange && <p className="form-error" role="alert">A data final do período deve ser igual ou posterior à inicial.</p>}

      <QueryState isLoading={q.isLoading && !invalidRange} error={q.error} empty={!invalidRange && q.data?.data.length === 0} emptyText="Nenhuma autorização encontrada com esses filtros." onRetry={() => q.refetch()}>
        {q.data && !invalidRange && (
          <>
            <div className="table-wrap">
              <table>
                <thead><tr><th>Pessoa</th><th>Local</th><th>Período</th><th>Horário</th><th>Usos restantes</th><th>Situação</th><th><span className="sr-only">Ações</span></th></tr></thead>
                <tbody>
                  {q.data.data.map((a) => (
                    <tr key={a.id}>
                      <td>{a.user?.name ?? "—"}</td>
                      <td>{locationLabel(a.location)}</td>
                      <td>{formatDateOnly(a.startDate)} a {formatDateOnly(a.endDate)}</td>
                      <td>{a.startTime} às {a.endTime}</td>
                      <td>{a.remainingUses === null ? "Ilimitado" : `${a.remainingUses} de ${a.maxUses}`}</td>
                      <td><Badge tone={a.status === "ACTIVE" ? "ok" : a.status === "EXPIRED" ? "warn" : "muted"}>{STATUS_LABEL[a.status]}</Badge></td>
                      <td className="row-actions">
                        {a.status === "ACTIVE" && <button className="btn btn-danger btn-sm" onClick={() => setCanceling(a)}>Cancelar</button>}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <Pagination page={q.data.page} totalPages={q.data.totalPages} total={q.data.total} onPage={setPage} />
          </>
        )}
      </QueryState>

      {creating && <CreateForm onClose={() => setCreating(false)} />}
      {canceling && (
        <ConfirmDialog
          title="Cancelar autorização?"
          message={`${canceling.user?.name ?? "A pessoa"} perderá o acesso a ${locationLabel(canceling.location)}. Essa ação não pode ser desfeita; o registro continua visível como cancelado.`}
          confirmLabel="Cancelar autorização"
          danger
          busy={cancel.isPending}
          error={cancel.error}
          onConfirm={() => cancel.mutate(canceling.id)}
          onCancel={() => { cancel.reset(); setCanceling(null); }}
        />
      )}
    </>
  );
}
