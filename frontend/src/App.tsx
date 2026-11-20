import { lazy, Suspense } from "react";
import { Navigate, Route, Routes } from "react-router-dom";
import Layout from "./Layout";
import LoginPage from "./features/auth/LoginPage";
import UsersPage from "./features/users/UsersPage";
import UserFormPage from "./features/users/UserFormPage";
import UserDetailPage from "./features/users/UserDetailPage";
import LocationsPage from "./features/locations/LocationsPage";
import TerminalsPage from "./features/locations/TerminalsPage";
import AuthorizationsPage from "./features/authorizations/AuthorizationsPage";
import AuthorizationDetailPage from "./features/authorizations/AuthorizationDetailPage";
import AccessLogsPage from "./features/access-logs/AccessLogsPage";

// O painel traz o Recharts (pesado): só é baixado quando a tela é aberta.
const DashboardPage = lazy(() => import("./features/dashboard/DashboardPage"));

export default function App() {
  return (
    <Suspense fallback={<p className="state" role="status">Carregando…</p>}>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route element={<Layout />}>
          <Route path="/painel" element={<DashboardPage />} />
          <Route path="/usuarios" element={<UsersPage />} />
          <Route path="/usuarios/novo" element={<UserFormPage />} />
          <Route path="/usuarios/:id" element={<UserDetailPage />} />
          <Route path="/usuarios/:id/editar" element={<UserFormPage />} />
          <Route path="/locais" element={<LocationsPage />} />
          <Route path="/terminais" element={<TerminalsPage />} />
          <Route path="/autorizacoes" element={<AuthorizationsPage />} />
          <Route path="/autorizacoes/:id" element={<AuthorizationDetailPage />} />
          <Route path="/historico" element={<AccessLogsPage />} />
        </Route>
        <Route path="*" element={<Navigate to="/painel" replace />} />
      </Routes>
    </Suspense>
  );
}
