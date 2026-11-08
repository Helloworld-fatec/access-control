import { useState } from "react";
import { Navigate, useLocation, useNavigate } from "react-router-dom";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { useAuth } from "./AuthContext";
import { Field, errorMessage } from "../../shared/ui";

const schema = z.object({
  email: z.string().trim().min(1, "Informe o e-mail").email("E-mail inválido"),
  password: z.string().min(1, "Informe a senha"),
});
type Values = z.infer<typeof schema>;

export default function LoginPage() {
  const { user, login, notice } = useAuth();
  const nav = useNavigate();
  const from = (useLocation().state as { from?: string } | null)?.from ?? "/usuarios";
  const [showPw, setShowPw] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const { register, handleSubmit, formState } = useForm<Values>({ resolver: zodResolver(schema) });

  if (user) return <Navigate to={from} replace />;

  const onSubmit = handleSubmit(async (v) => {
    setError(null);
    try {
      await login(v.email, v.password);
      nav(from, { replace: true });
    } catch (e) {
      setError(errorMessage(e));
    }
  });

  return (
    <main className="login">
      <form className="login-card" onSubmit={onSubmit} noValidate>
        <h1>Controle de acesso</h1>
        <p className="muted">Entre com sua conta de administrador.</p>
        {import.meta.env.VITE_MOCK === "true" && <p className="form-notice">Demonstração: entre com admin@teste.com e qualquer senha.</p>}
        {notice && <p className="form-notice" role="status">{notice}</p>}
        <Field label="E-mail" error={formState.errors.email?.message}>
          <input type="email" autoComplete="username" {...register("email")} />
        </Field>
        <Field label="Senha" error={formState.errors.password?.message}>
          <input type={showPw ? "text" : "password"} autoComplete="current-password" {...register("password")} />
        </Field>
        <label className="check">
          <input type="checkbox" checked={showPw} onChange={(e) => setShowPw(e.target.checked)} /> Mostrar senha
        </label>
        {error && <p className="form-error" role="alert">{error}</p>}
        <button className="btn btn-primary btn-block" disabled={formState.isSubmitting}>
          {formState.isSubmitting ? "Entrando…" : "Entrar"}
        </button>
      </form>
    </main>
  );
}
