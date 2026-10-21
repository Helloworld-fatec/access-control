import { useState } from "react";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "../../shared/api";
import { applyApiErrors } from "../../shared/forms";
import { useLocationOptions } from "../../shared/lookups";
import type { Paginated, Terminal, TerminalCreated } from "../../shared/types";
import { formatDateTime, locationLabel } from "../../shared/format";
import { Badge, ConfirmDialog, Field, Modal, PageHeader, Pagination, QueryState } from "../../shared/ui";

const coord = (min: number, max: number, label: string) =>
  z.string().trim().refine((v) => v !== "" && !Number.isNaN(Number(v.replace(",", "."))) && Number(v.replace(",", ".")) >= min && Number(v.replace(",", ".")) <= max, `${label} deve estar entre ${min} e ${max}`);

const schema = z.object({
  name: z.string().trim().min(1, "Informe o nome do terminal"),
  locationId: z.string().min(1, "Escolha o local"),
  latitude: coord(-90, 90, "Latitude"),
  longitude: coord(-180, 180, "Longitude"),
});
type Values = z.infer<typeof schema>;
const num = (v: string) => Number(v.replace(",", "."));

function TerminalForm({ initial, onClose, onCreated }: { initial: Terminal | null; onClose: () => void; onCreated: (t: TerminalCreated) => void }) {
  const qc = useQueryClient();
  const locations = useLocationOptions();
  const [formError, setFormError] = useState<string | null>(null);
  const { register, handleSubmit, setError, formState } = useForm<Values>({
    resolver: zodResolver(schema),
    defaultValues: {
      name: initial?.name ?? "",
      locationId: initial?.locationId ?? "",
      latitude: initial ? String(initial.latitude) : "",
      longitude: initial ? String(initial.longitude) : "",
    },
  });
  const save = useMutation({
    mutationFn: (v: Values) => {
      const body = { name: v.name, locationId: v.locationId, latitude: num(v.latitude), longitude: num(v.longitude) };
      return initial ? api<Terminal>(`/terminals/${initial.id}`, { method: "PUT", body }) : api<TerminalCreated>("/terminals", { method: "POST", body });
    },
    onSuccess: (t) => {
      qc.invalidateQueries({ queryKey: ["terminals"] });
      qc.invalidateQueries({ queryKey: ["options"] });
      if (!initial) onCreated(t as TerminalCreated);
      onClose();
    },
  });
  const onSubmit = handleSubmit(async (v) => {
    setFormError(null);
    try {
      await save.mutateAsync(v);
    } catch (e) {
      setFormError(applyApiErrors(e, setError, ["name", "locationId", "latitude", "longitude"]));
    }
  });
  return (
    <Modal title={initial ? "Editar terminal" : "Novo terminal"} onClose={onClose}>
      <form className="form" onSubmit={onSubmit} noValidate>
        <Field label="Nome do terminal" error={formState.errors.name?.message}><input {...register("name")} /></Field>
        <Field label="Local" error={formState.errors.locationId?.message}>
          <select {...register("locationId")}>
            <option value="">Escolha um local</option>
            {locations.data?.data.map((l) => <option key={l.id} value={l.id}>{locationLabel(l)}</option>)}
          </select>
        </Field>
        <div className="grid-2">
          <Field label="Latitude" hint="Coordenada fixa do terminal" error={formState.errors.latitude?.message}><input inputMode="decimal" {...register("latitude")} /></Field>
          <Field label="Longitude" error={formState.errors.longitude?.message}><input inputMode="decimal" {...register("longitude")} /></Field>
        </div>
        {formError && <p className="form-error" role="alert">{formError}</p>}
        <div className="actions">
          <button type="button" className="btn" onClick={onClose}>Cancelar</button>
          <button className="btn btn-primary" disabled={formState.isSubmitting}>{formState.isSubmitting ? "Salvando…" : "Salvar terminal"}</button>
        </div>
      </form>
    </Modal>
  );
}

export default function TerminalsPage() {
  const qc = useQueryClient();
  const [page, setPage] = useState(1);
  const [editing, setEditing] = useState<Terminal | "new" | null>(null);
  const [deleting, setDeleting] = useState<Terminal | null>(null);
  const [created, setCreated] = useState<TerminalCreated | null>(null);
  const [copied, setCopied] = useState(false);

  const q = useQuery({
    queryKey: ["terminals", { page }],
    queryFn: () => api<Paginated<Terminal>>("/terminals", { query: { page, pageSize: 20 } }),
    placeholderData: keepPreviousData,
  });
  const locations = useLocationOptions();
  const locName = (t: Terminal) => locationLabel(t.location ?? locations.data?.data.find((l) => l.id === t.locationId));

  const remove = useMutation({
    mutationFn: (id: string) => api(`/terminals/${id}`, { method: "DELETE" }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["terminals"] });
      qc.invalidateQueries({ queryKey: ["options"] });
      setDeleting(null);
    },
  });

  return (
    <>
      <PageHeader title="Terminais">
        <button className="btn btn-primary" onClick={() => setEditing("new")}>Novo terminal</button>
      </PageHeader>
      <QueryState isLoading={q.isLoading} error={q.error} empty={q.data?.data.length === 0} emptyText="Nenhum terminal cadastrado." onRetry={() => q.refetch()}>
        {q.data && (
          <>
            <div className="table-wrap">
              <table>
                <thead><tr><th>Terminal</th><th>Local</th><th>Estado</th><th>Última presença</th><th>Coordenada</th><th><span className="sr-only">Ações</span></th></tr></thead>
                <tbody>
                  {q.data.data.map((t) => (
                    <tr key={t.id}>
                      <td>{t.name}</td>
                      <td>{locName(t)}</td>
                      <td><Badge tone={t.online ? "ok" : "muted"}>{t.online ? "Online" : "Offline"}</Badge></td>
                      <td>{formatDateTime(t.lastPresenceAt)}</td>
                      <td className="nums">{t.latitude.toFixed(5)}, {t.longitude.toFixed(5)}</td>
                      <td className="row-actions">
                        <button className="btn btn-sm" onClick={() => setEditing(t)}>Editar</button>
                        <button className="btn btn-danger btn-sm" onClick={() => setDeleting(t)}>Excluir</button>
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

      {editing && <TerminalForm initial={editing === "new" ? null : editing} onClose={() => setEditing(null)} onCreated={setCreated} />}

      {created && (
        <Modal title="Terminal criado" onClose={() => { setCreated(null); setCopied(false); }}>
          <p>Copie a chave abaixo e configure no aplicativo mobile-readings. <strong>Ela aparece só desta vez.</strong></p>
          <p className="keybox"><code>{created.apiKey}</code></p>
          <div className="actions">
            <button className="btn" onClick={async () => { await navigator.clipboard?.writeText(created.apiKey); setCopied(true); }}>
              {copied ? "Chave copiada" : "Copiar chave"}
            </button>
            <button className="btn btn-primary" onClick={() => { setCreated(null); setCopied(false); }}>Já guardei a chave</button>
          </div>
        </Modal>
      )}

      {deleting && (
        <ConfirmDialog
          title="Excluir terminal?"
          message={`O terminal "${deleting.name}" será removido e sua chave deixará de funcionar.`}
          confirmLabel="Excluir terminal"
          danger
          busy={remove.isPending}
          error={remove.error}
          onConfirm={() => remove.mutate(deleting.id)}
          onCancel={() => { remove.reset(); setDeleting(null); }}
        />
      )}
    </>
  );
}
