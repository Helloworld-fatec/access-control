import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api, apiBlob } from "../../shared/api";
import type { Authorization, Paginated, UserDetail } from "../../shared/types";
import { formatDateOnly, formatDateTime, locationLabel, normalizeUid, ROLE_LABEL, STATUS_LABEL } from "../../shared/format";
import { Badge, ConfirmDialog, errorMessage, PageHeader, QueryState } from "../../shared/ui";

type Confirm = { kind: "status" } | { kind: "tag"; tagId: string; uid: string } | { kind: "face" } | null;

export default function UserDetailPage() {
  const { id } = useParams();
  const qc = useQueryClient();
  const [confirm, setConfirm] = useState<Confirm>(null);
  const [uid, setUid] = useState("");
  const [tagError, setTagError] = useState<string | null>(null);

  const user = useQuery({ queryKey: ["user", id], queryFn: () => api<UserDetail>(`/users/${id}`) });
  const auths = useQuery({
    queryKey: ["authorizations", { userId: id, page: 1 }],
    queryFn: () => api<Paginated<Authorization>>("/authorizations", { query: { userId: id, pageSize: 10 } }),
  });

  // <img> não envia Authorization: busca a foto com fetch e exibe via object URL.
  const [photoUrl, setPhotoUrl] = useState<string | null>(null);
  const hasPhoto = user.data?.hasPhoto;
  useEffect(() => {
    if (!hasPhoto) return setPhotoUrl(null);
    let url: string | null = null;
    let cancelled = false;
    apiBlob(`/users/${id}/photo`)
      .then((b) => {
        if (cancelled) return;
        url = URL.createObjectURL(b);
        setPhotoUrl(url);
      })
      .catch(() => setPhotoUrl(null));
    return () => {
      cancelled = true;
      if (url) URL.revokeObjectURL(url);
    };
  }, [hasPhoto, id]);

  const refresh = () => {
    qc.invalidateQueries({ queryKey: ["user", id] });
    qc.invalidateQueries({ queryKey: ["users"] });
    setConfirm(null);
  };

  const toggle = useMutation({
    mutationFn: () => api(`/users/${id}/status`, { method: "PATCH", body: { active: !user.data!.active } }),
    onSuccess: refresh,
  });
  const removeTag = useMutation({
    mutationFn: (tagId: string) => api(`/users/${id}/tags/${tagId}`, { method: "DELETE" }),
    onSuccess: refresh,
  });
  const removeFace = useMutation({
    mutationFn: () => api(`/users/${id}/face`, { method: "DELETE" }),
    onSuccess: refresh,
  });
  const addTag = useMutation({
    mutationFn: (value: string) => api(`/users/${id}/tags`, { method: "POST", body: { uid: value } }),
    onSuccess: () => {
      setUid("");
      setTagError(null);
      refresh();
    },
    onError: (e) => setTagError(errorMessage(e)),
  });

  const u = user.data;
  return (
    <>
      <PageHeader title={u?.name ?? "Usuário"}>
        <Link className="btn" to="/usuarios">Voltar à lista</Link>
        {u && <Link className="btn" to={`/usuarios/${u.id}/editar`}>Editar dados</Link>}
        {u && (
          <button className={u.active ? "btn btn-danger" : "btn btn-primary"} onClick={() => setConfirm({ kind: "status" })}>
            {u.active ? "Desativar" : "Reativar"}
          </button>
        )}
      </PageHeader>

      <QueryState isLoading={user.isLoading} error={user.error} empty={!u} emptyText="Usuário não encontrado." onRetry={() => user.refetch()}>
        {u && (
          <div className="stack">
            <section className="panel profile">
              {photoUrl ? <img className="photo" src={photoUrl} alt={`Foto de ${u.name}`} /> : <div className="photo photo-empty" aria-label="Sem foto cadastrada">Sem foto</div>}
              <dl className="facts">
                <div><dt>Perfil</dt><dd>{ROLE_LABEL[u.role]}</dd></div>
                <div><dt>Situação</dt><dd><Badge tone={u.active ? "ok" : "muted"}>{u.active ? "Ativo" : "Inativo"}</Badge></dd></div>
                <div><dt>E-mail</dt><dd>{u.email}</dd></div>
                <div><dt>Documento</dt><dd>{u.document ?? "—"}</dd></div>
                <div><dt>Telefone</dt><dd>{u.phone ?? "—"}</dd></div>
                <div><dt>Cadastrado em</dt><dd>{formatDateTime(u.createdAt)}</dd></div>
              </dl>
            </section>

            <section className="panel">
              <h2>Tags NFC</h2>
              {u.nfcTags.length === 0 ? <p className="muted">Nenhuma tag vinculada.</p> : (
                <ul className="list">
                  {u.nfcTags.map((t) => (
                    <li key={t.id}>
                      <code>{t.uid}</code>
                      <button className="btn btn-danger btn-sm" onClick={() => setConfirm({ kind: "tag", tagId: t.id, uid: t.uid })}>Remover</button>
                    </li>
                  ))}
                </ul>
              )}
              <form
                className="inline-form"
                onSubmit={(e) => {
                  e.preventDefault();
                  const v = normalizeUid(uid);
                  if (v) addTag.mutate(v);
                }}
              >
                <label className="field">
                  <span className="field-label">UID da tag</span>
                  <input value={uid} onChange={(e) => setUid(e.target.value)} placeholder="04A32F1B" autoComplete="off" spellCheck={false} />
                  <span className="field-hint">Use o leitor USB ou digite. Separadores e minúsculas são ajustados.</span>
                  {tagError && <span className="field-error" role="alert">{tagError}</span>}
                </label>
                <button className="btn btn-primary" disabled={addTag.isPending || !uid.trim()}>Vincular tag</button>
              </form>
            </section>

            <section className="panel">
              <h2>Reconhecimento facial</h2>
              <p>
                {u.hasFace ? <Badge tone="ok">Rosto cadastrado</Badge> : <Badge tone="muted">Sem rosto cadastrado</Badge>}
              </p>
              {!u.hasFace && <p className="muted">O cadastro facial é feito no aplicativo mobile-registry.</p>}
              {u.hasFace && (
                <button className="btn btn-danger" onClick={() => setConfirm({ kind: "face" })}>Excluir dados biométricos</button>
              )}
            </section>

            <section className="panel">
              <div className="row spread">
                <h2>Autorizações</h2>
                <Link className="btn" to="/autorizacoes">Gerenciar autorizações</Link>
              </div>
              <QueryState isLoading={auths.isLoading} error={auths.error} empty={auths.data?.data.length === 0} emptyText="Este usuário ainda não tem autorizações." onRetry={() => auths.refetch()}>
                <div className="table-wrap">
                  <table>
                    <thead><tr><th>Local</th><th>Período</th><th>Horário</th><th>Situação</th></tr></thead>
                    <tbody>
                      {auths.data?.data.map((a) => (
                        <tr key={a.id}>
                          <td>{locationLabel(a.location)}</td>
                          <td>{formatDateOnly(a.startDate)} a {formatDateOnly(a.endDate)}</td>
                          <td>{a.startTime} às {a.endTime}</td>
                          <td><Badge tone={a.status === "ACTIVE" ? "ok" : "muted"}>{STATUS_LABEL[a.status]}</Badge></td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </QueryState>
            </section>
          </div>
        )}
      </QueryState>

      {confirm?.kind === "status" && u && (
        <ConfirmDialog
          title={u.active ? "Desativar usuário?" : "Reativar usuário?"}
          message={u.active ? `${u.name} não conseguirá mais acessar nenhum local. O histórico de acessos é mantido.` : `${u.name} voltará a poder usar suas autorizações.`}
          confirmLabel={u.active ? "Desativar" : "Reativar"}
          danger={u.active}
          busy={toggle.isPending}
          error={toggle.error}
          onConfirm={() => toggle.mutate()}
          onCancel={() => setConfirm(null)}
        />
      )}
      {confirm?.kind === "tag" && (
        <ConfirmDialog
          title="Remover tag?"
          message={`A tag ${confirm.uid} deixará de abrir portas para este usuário.`}
          confirmLabel="Remover tag"
          danger
          busy={removeTag.isPending}
          error={removeTag.error}
          onConfirm={() => removeTag.mutate(confirm.tagId)}
          onCancel={() => setConfirm(null)}
        />
      )}
      {confirm?.kind === "face" && (
        <ConfirmDialog
          title="Excluir dados biométricos?"
          message="O vetor facial e a foto serão removidos de forma definitiva. Essa ação não pode ser desfeita."
          confirmLabel="Excluir definitivamente"
          danger
          busy={removeFace.isPending}
          error={removeFace.error}
          onConfirm={() => removeFace.mutate()}
          onCancel={() => setConfirm(null)}
        />
      )}
    </>
  );
}
