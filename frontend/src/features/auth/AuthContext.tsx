import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { api, ApiError, setAccessToken, setUnauthorizedHandler } from "../../shared/api";
import type { User } from "../../shared/types";

interface AuthValue {
  user: User | null;
  notice: string | null;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
}

const Ctx = createContext<AuthValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const qc = useQueryClient();
  // Sessão só em memória: nada de localStorage (US-03, US-19). Recarregar a página pede novo login.
  const [user, setUser] = useState<User | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const clear = useCallback(() => {
    setAccessToken(null);
    setUser(null);
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
    const r = await api<{ accessToken: string; user: User }>("/login", {
      method: "POST",
      body: { email, password },
      authenticated: false,
    });
    if (r.user.role !== "ADMIN") throw new ApiError(403, "FORBIDDEN", "Apenas administradores podem entrar neste sistema.");
    qc.clear();
    setAccessToken(r.accessToken);
    setUser(r.user);
  }, [qc]);

  const value = useMemo(() => ({ user, notice, login, logout }), [user, notice, login, logout]);
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useAuth(): AuthValue {
  const v = useContext(Ctx);
  if (!v) throw new Error("useAuth fora do AuthProvider");
  return v;
}
