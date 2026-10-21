import { useState } from "react";
import { Link } from "react-router-dom";
import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { api } from "../../shared/api";
import type { Paginated, Role, User } from "../../shared/types";
import { ROLE_LABEL } from "../../shared/format";
import { Badge, PageHeader, Pagination, QueryState } from "../../shared/ui";

export default function UsersPage() {
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [role, setRole] = useState<"" | Role>("");
  const [active, setActive] = useState<"" | "true" | "false">("");

  const q = useQuery({
    queryKey: ["users", { page, search, role, active }],
    queryFn: () => api<Paginated<User>>("/users", { query: { page, pageSize: 20, search: search.trim(), role, active } }),
    placeholderData: keepPreviousData,
  });
  const reset = <T,>(set: (v: T) => void) => (v: T) => {
    set(v);
    setPage(1);
  };

  return (
    <>
      <PageHeader title="Usuários">
        <Link className="btn btn-primary" to="/usuarios/novo">Novo usuário</Link>
      </PageHeader>

      <div className="filters">
        <label className="field">
          <span className="field-label">Buscar por nome ou documento</span>
          <input type="search" value={search} onChange={(e) => reset(setSearch)(e.target.value)} />
        </label>
        <label className="field">
          <span className="field-label">Perfil</span>
          <select value={role} onChange={(e) => reset(setRole)(e.target.value as "" | Role)}>
            <option value="">Todos</option>
            {(Object.keys(ROLE_LABEL) as Role[]).map((r) => <option key={r} value={r}>{ROLE_LABEL[r]}</option>)}
          </select>
        </label>
        <label className="field">
          <span className="field-label">Situação</span>
          <select value={active} onChange={(e) => reset(setActive)(e.target.value as "" | "true" | "false")}>
            <option value="">Todas</option>
            <option value="true">Ativos</option>
            <option value="false">Inativos</option>
          </select>
        </label>
      </div>

      <QueryState isLoading={q.isLoading} error={q.error} empty={q.data?.data.length === 0} emptyText="Nenhum usuário encontrado com esses filtros." onRetry={() => q.refetch()}>
        {q.data && (
          <>
            <div className="table-wrap">
              <table>
                <thead>
                  <tr><th>Nome</th><th>Perfil</th><th>Situação</th><th>E-mail</th><th>Telefone</th></tr>
                </thead>
                <tbody>
                  {q.data.data.map((u) => (
                    <tr key={u.id}>
                      <td><Link to={`/usuarios/${u.id}`}>{u.name}</Link></td>
                      <td>{ROLE_LABEL[u.role]}</td>
                      <td><Badge tone={u.active ? "ok" : "muted"}>{u.active ? "Ativo" : "Inativo"}</Badge></td>
                      <td>{u.email}</td>
                      <td>{u.phone ?? "—"}</td>
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
