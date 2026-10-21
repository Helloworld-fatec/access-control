import { Navigate, Route, Routes } from "react-router-dom";
import Layout from "./Layout";
import LoginPage from "./features/auth/LoginPage";
import UsersPage from "./features/users/UsersPage";
import UserFormPage from "./features/users/UserFormPage";
import UserDetailPage from "./features/users/UserDetailPage";
import LocationsPage from "./features/locations/LocationsPage";
import TerminalsPage from "./features/locations/TerminalsPage";
import AuthorizationsPage from "./features/authorizations/AuthorizationsPage";
import AccessLogsPage from "./features/access-logs/AccessLogsPage";

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route element={<Layout />}>
        <Route path="/usuarios" element={<UsersPage />} />
        <Route path="/usuarios/novo" element={<UserFormPage />} />
        <Route path="/usuarios/:id" element={<UserDetailPage />} />
        <Route path="/usuarios/:id/editar" element={<UserFormPage />} />
        <Route path="/locais" element={<LocationsPage />} />
        <Route path="/terminais" element={<TerminalsPage />} />
        <Route path="/autorizacoes" element={<AuthorizationsPage />} />
        <Route path="/historico" element={<AccessLogsPage />} />
      </Route>
      <Route path="*" element={<Navigate to="/usuarios" replace />} />
    </Routes>
  );
}
