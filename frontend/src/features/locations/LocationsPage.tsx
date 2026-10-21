import { useState } from "react";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "../../shared/api";
import { applyApiErrors } from "../../shared/forms";
import type { Location, Paginated } from "../../shared/types";
import { ConfirmDialog, Field, Modal, PageHeader, Pagination, QueryState } from "../../shared/ui";

const schema = z.object({
  building: z.string().trim().min(1, "Informe o edifício"),
  entrance: z.string().trim(),
  door: z.string().trim(),
  turnstile: z.string().trim(),
  description: z.string().trim(),
});
type Values = z.infer<typeof schema>;
const FIELDS = ["building", "entrance", "door", "turnstile", "description"];

function LocationForm({ initial, onClose }: { initial: Location | null; onClose: () => void }) {
  const qc = useQueryClient();
  const [formError, setFormError] = useState<string | null>(null);
  const { register, handleSubmit, setError, formState } = useForm<Values>({
    resolver: zodResolver(schema),
    defaultValues: {
      building: initial?.building ?? "",
      entrance: initial?.entrance ?? "",
      door: initial?.door ?? "",
      turnstile: initial?.turnstile ?? "",
      description: initial?.description ?? "",
    },
  });
  const save = useMutation({
    mutationFn: (v: Values) =>
      initial ? api(`/locations/${initial.id}`, { method: "PUT", body: v }) : api("/locations", { method: "POST", body: v }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["locations"] });
      qc.invalidateQueries({ queryKey: ["options"] });
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
    <Modal title={initial ? "Editar local" : "Novo local"} onClose={onClose}>
      <form className="form" onSubmit={onSubmit} noValidate>
        <Field label="Edifício" error={formState.errors.building?.message}><input {...register("building")} /></Field>
        <div className="grid-2">
          <Field label="Portaria (opcional)"><input {...register("entrance")} /></Field>
          <Field label="Porta (opcional)"><input {...register("door")} /></Field>
        </div>
        <Field label="Catraca (opcional)"><input {...register("turnstile")} /></Field>
        <Field label="Descrição (opcional)"><textarea rows={3} {...register("description")} /></Field>
        {formError && <p className="form-error" role="alert">{formError}</p>}
        <div className="actions">
          <button type="button" className="btn" onClick={onClose}>Cancelar</button>
          <button className="btn btn-primary" disabled={formState.isSubmitting}>{formState.isSubmitting ? "Salvando…" : "Salvar local"}</button>
        </div>
      </form>
    </Modal>
  );
}

export default function LocationsPage() {
  const qc = useQueryClient();
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [editing, setEditing] = useState<Location | "new" | null>(null);
  const [deleting, setDeleting] = useState<Location | null>(null);

  const q = useQuery({
    queryKey: ["locations", { page, search }],
    queryFn: () => api<Paginated<Location>>("/locations", { query: { page, pageSize: 20, search: search.trim() } }),
    placeholderData: keepPreviousData,
  });
  const remove = useMutation({
    mutationFn: (id: string) => api(`/locations/${id}`, { method: "DELETE" }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["locations"] });
      qc.invalidateQueries({ queryKey: ["options"] });
      setDeleting(null);
    },
  });

  return (
    <>
      <PageHeader title="Locais">
        <button className="btn btn-primary" onClick={() => setEditing("new")}>Novo local</button>
      </PageHeader>
      <div className="filters">
        <label className="field">
          <span className="field-label">Buscar local</span>
          <input type="search" value={search} onChange={(e) => { setSearch(e.target.value); setPage(1); }} />
        </label>
      </div>
      <QueryState isLoading={q.isLoading} error={q.error} empty={q.data?.data.length === 0} emptyText="Nenhum local cadastrado. Cadastre o primeiro para criar autorizações." onRetry={() => q.refetch()}>
        {q.data && (
          <>
            <div className="table-wrap">
              <table>
                <thead><tr><th>Edifício</th><th>Portaria</th><th>Porta</th><th>Catraca</th><th>Descrição</th><th><span className="sr-only">Ações</span></th></tr></thead>
                <tbody>
                  {q.data.data.map((l) => (
                    <tr key={l.id}>
                      <td>{l.building}</td><td>{l.entrance ?? "—"}</td><td>{l.door ?? "—"}</td><td>{l.turnstile ?? "—"}</td><td>{l.description ?? "—"}</td>
                      <td className="row-actions">
                        <button className="btn btn-sm" onClick={() => setEditing(l)}>Editar</button>
                        <button className="btn btn-danger btn-sm" onClick={() => setDeleting(l)}>Excluir</button>
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
      {editing && <LocationForm initial={editing === "new" ? null : editing} onClose={() => setEditing(null)} />}
      {deleting && (
        <ConfirmDialog
          title="Excluir local?"
          message={`O local "${deleting.building}" será removido. Se houver terminais ou autorizações vinculados, o servidor vai recusar.`}
          confirmLabel="Excluir local"
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
