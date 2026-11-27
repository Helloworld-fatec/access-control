import { Navigate, NavLink, Outlet, useLocation } from "react-router-dom";
import { useAuth } from "./features/auth/AuthContext";
import Logo from "./shared/Logo";

const NAV = [
  { to: "/painel", label: "Painel" },
  { to: "/visitas", label: "Dentro e saídas" },
  { to: "/usuarios", label: "Usuários" },
  { to: "/locais", label: "Locais" },
  { to: "/terminais", label: "Terminais" },
  { to: "/autorizacoes", label: "Autorizações" },
  { to: "/historico", label: "Histórico de acessos" },
];

/** Protege as rotas: só administrador logado. O backend continua sendo a barreira real. */
export default function Layout() {
  const { user, logout } = useAuth();
  const loc = useLocation();
  if (!user) return <Navigate to="/login" state={{ from: loc.pathname }} replace />;
  if (user.role !== "ADMIN") return <Navigate to="/login" replace />;

  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand">
          <Logo size={42} />
          <span>Controle de acesso</span>
        </div>
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
        {import.meta.env.VITE_MOCK === "true" && (
          <p className="dev-banner" role="note">
            Modo demonstração: os dados são fictícios, ficam só no navegador e voltam ao início ao recarregar a página.
          </p>
        )}
        <Outlet />
      </main>
      <footer className="hints" aria-label="Atalhos do teclado">
        <span><kbd>Tab</kbd> Navegar</span>
        <span><kbd>Enter</kbd> Confirmar</span>
        <span><kbd>Esc</kbd> Fechar janela</span>
      </footer>
    </div>
  );
}
