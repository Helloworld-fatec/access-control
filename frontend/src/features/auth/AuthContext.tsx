import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { api, ApiError, setAccessToken, setUnauthorizedHandler } from "../../shared/api";
import type { Paginated, User } from "../../shared/types";

interface AuthValue {
  user: User | null;
  /** true enquanto o backend não tem /auth/login: entrou sem validar senha. */
  devMode: boolean;
  notice: string | null;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
}

const Ctx = createContext<AuthValue | null>(null);
const DEV_AUTH = import.meta.env.VITE_DEV_AUTH !== "false";

export function AuthProvider({ children }: { children: ReactNode }) {
  const qc = useQueryClient();
  // Sessão só em memória: nada de localStorage (US-03, US-19). Recarregar a página pede novo login.
  const [user, setUser] = useState<User | null>(null);
  const [devMode, setDevMode] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);

  const clear = useCallback(() => {
    setAccessToken(null);
    setUser(null);
    setDevMode(false);
    qc.clear();
  }, [qc]);

  const logout = useCallback(() => {
    setNotice(null);
    clear();
  }, [clear]);

  useEffect(() => {
    setUnauthorizedHandler(() => {
      clear();
      setNotice("Sua sessão expirou. Entre novamente.");
    });
    return () => setUnauthorizedHandler(null);
  }, [clear]);

  const login = useCallback(async (email: string, password: string) => {
    setNotice(null);
    try {
      const r = await api<{ accessToken: string; user: User }>("/auth/login", { method: "POST", body: { email, password } });
      if (r.user.role !== "ADMIN") throw new ApiError(403, "FORBIDDEN", "Apenas administradores podem entrar neste sistema.");
      setAccessToken(r.accessToken);
      setUser(r.user);
      setDevMode(false);
    } catch (e) {
      // Backend ainda sem /auth/login (404): entra como o administrador cadastrado com esse e-mail.
      if (!(DEV_AUTH && e instanceof ApiError && e.status === 404)) throw e;
      const list = await api<Paginated<User>>("/users", { query: { role: "ADMIN", active: true, pageSize: 100 } });
      const found = list.data.find((u) => u.email.toLowerCase() === email.trim().toLowerCase());
      if (!found) throw new ApiError(401, "INVALID_CREDENTIALS", "Nenhum administrador ativo com esse e-mail.");
      setUser(found);
      setDevMode(true);
    }
  }, []);

  const value = useMemo(() => ({ user, devMode, notice, login, logout }), [user, devMode, notice, login, logout]);
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useAuth(): AuthValue {
  const v = useContext(Ctx);
  if (!v) throw new Error("useAuth fora do AuthProvider");
  return v;
}
