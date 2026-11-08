import { Navigate, NavLink, Outlet, useLocation } from "react-router-dom";
import { useAuth } from "./features/auth/AuthContext";

const NAV = [
  { to: "/usuarios", label: "Usuários" },
  { to: "/locais", label: "Locais" },
  { to: "/terminais", label: "Terminais" },
  { to: "/autorizacoes", label: "Autorizações" },
  { to: "/historico", label: "Histórico de acessos" },
];

/** Protege as rotas: só administrador logado. O backend continua sendo a barreira real. */
export default function Layout() {
  const { user, devMode, logout } = useAuth();
  const loc = useLocation();
  if (!user) return <Navigate to="/login" state={{ from: loc.pathname }} replace />;
  if (user.role !== "ADMIN") return <Navigate to="/login" replace />;

  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand">Controle de acesso</div>
        <nav aria-label="Principal">
          {NAV.map((n) => (
            <NavLink key={n.to} to={n.to} className={({ isActive }) => (isActive ? "nav-link active" : "nav-link")}>
              {n.label}
            </NavLink>
          ))}
        </nav>
        <div className="sidebar-foot">
          <div className="who">{user.name}</div>
          <button className="btn btn-ghost" onClick={logout}>Sair</button>
        </div>
      </aside>
      <main className="content">
        {devMode && (
          <p className="dev-banner" role="note">
            Modo de desenvolvimento: o backend ainda não tem login, então a senha não foi conferida.
          </p>
        )}
        {import.meta.env.VITE_MOCK === "true" && (
          <p className="dev-banner" role="note">
            Modo demonstração: os dados são fictícios, ficam só no navegador e voltam ao início ao recarregar a página.
          </p>
        )}
        <Outlet />
      </main>
    </div>
  );
}
