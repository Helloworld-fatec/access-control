import { useEffect, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "../../shared/api";
import { applyApiErrors } from "../../shared/forms";
import type { Role, User, UserDetail } from "../../shared/types";
import { ROLE_LABEL } from "../../shared/format";
import { Field, PageHeader, QueryState } from "../../shared/ui";

const FIELDS = ["name", "email", "document", "phone", "role", "password"];

// A senha é obrigatória só na criação; na edição, em branco mantém a atual.
const makeSchema = (editing: boolean) =>
  z.object({
    name: z.string().trim().min(2, "Informe o nome completo"),
    email: z.string().trim().min(1, "Informe o e-mail").email("E-mail inválido"),
    document: z.string().trim(),
    phone: z.string().trim(),
    role: z.enum(["ADMIN", "RESIDENT", "VISITOR"], { message: "Escolha o perfil" }),
    password: editing
      ? z.string().refine((v) => v === "" || v.length >= 6, "A senha deve ter ao menos 6 caracteres")
      : z.string().min(6, "A senha deve ter ao menos 6 caracteres"),
  });
type Values = z.infer<ReturnType<typeof makeSchema>>;

export default function UserFormPage() {
  const { id } = useParams();
  const editing = Boolean(id);
  const nav = useNavigate();
  const qc = useQueryClient();
  const [formError, setFormError] = useState<string | null>(null);

  const existing = useQuery({
    queryKey: ["user", id],
    queryFn: () => api<UserDetail>(`/users/${id}`),
    enabled: editing,
  });

  const { register, handleSubmit, reset, setError, formState } = useForm<Values>({
    resolver: zodResolver(makeSchema(editing)),
    defaultValues: { name: "", email: "", document: "", phone: "", role: "RESIDENT", password: "" },
  });

  useEffect(() => {
    if (existing.data) {
      const u = existing.data;
      reset({ name: u.name, email: u.email, document: u.document ?? "", phone: u.phone ?? "", role: u.role, password: "" });
    }
  }, [existing.data, reset]);

  const save = useMutation({
    mutationFn: (v: Values) => {
      const body: Record<string, unknown> = { name: v.name, email: v.email, document: v.document, phone: v.phone, role: v.role as Role };
      if (v.password) body.password = v.password;
      return editing
        ? api<User>(`/users/${id}`, { method: "PUT", body })
        : api<User>("/users", { method: "POST", body });
    },
    onSuccess: (u) => {
      qc.invalidateQueries({ queryKey: ["users"] });
      qc.invalidateQueries({ queryKey: ["user", u.id] });
      qc.invalidateQueries({ queryKey: ["options"] });
      nav(`/usuarios/${u.id}`);
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
    <>
      <PageHeader title={editing ? "Editar usuário" : "Novo usuário"} />
      <QueryState isLoading={editing && existing.isLoading} error={existing.error} empty={false} emptyText="" onRetry={() => existing.refetch()}>
        <form className="form" onSubmit={onSubmit} noValidate>
          <Field label="Nome completo" error={formState.errors.name?.message}>
            <input autoComplete="off" {...register("name")} />
          </Field>
          <Field label="E-mail (usado no login)" error={formState.errors.email?.message}>
            <input type="email" autoComplete="off" {...register("email")} />
          </Field>
          <div className="grid-2">
            <Field label="Documento (opcional)" error={formState.errors.document?.message}>
              <input autoComplete="off" {...register("document")} />
            </Field>
            <Field label="Telefone (opcional)" error={formState.errors.phone?.message}>
              <input type="tel" autoComplete="off" {...register("phone")} />
            </Field>
          </div>
          <div className="grid-2">
            <Field label="Perfil" error={formState.errors.role?.message}>
              <select {...register("role")}>
                {(Object.keys(ROLE_LABEL) as Role[]).map((r) => <option key={r} value={r}>{ROLE_LABEL[r]}</option>)}
              </select>
            </Field>
            <Field label={editing ? "Nova senha" : "Senha"} hint={editing ? "Deixe em branco para manter a atual." : undefined} error={formState.errors.password?.message}>
              <input type="password" autoComplete="new-password" {...register("password")} />
            </Field>
          </div>
          {formError && <p className="form-error" role="alert">{formError}</p>}
          <div className="actions">
            <Link className="btn" to={editing ? `/usuarios/${id}` : "/usuarios"}>Cancelar</Link>
            <button className="btn btn-primary" disabled={formState.isSubmitting}>
              {formState.isSubmitting ? "Salvando…" : "Salvar usuário"}
            </button>
          </div>
        </form>
      </QueryState>
    </>
  );
}
