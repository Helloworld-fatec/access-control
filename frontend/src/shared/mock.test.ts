import { beforeAll, describe, expect, it } from "vitest";
import { api, ApiError } from "./api";
import { installMock } from "./mock";
import type { Authorization, DashboardSummary, HourBucket, Paginated, TerminalStatus, User } from "./types";

// O modo demonstração precisa seguir o contrato do backend real.
describe("API simulada (modo demonstração)", () => {
  beforeAll(() => installMock({ live: false }));

  it("faz login em POST /login só para administradores ativos", async () => {
    const r = await api<{ accessToken: string; user: User }>("/login", { method: "POST", body: { email: "admin@teste.com", password: "x" } });
    expect(r.user.role).toBe("ADMIN");
    expect(r.accessToken).toBeTruthy();
    const err = (await api("/login", { method: "POST", body: { email: "marina@teste.com", password: "x" } }).catch((e) => e)) as ApiError;
    expect(err.status).toBe(401);
  });

  it("pagina e filtra usuários como o backend", async () => {
    const p = await api<Paginated<User>>("/users", { query: { pageSize: 2, role: "RESIDENT" } });
    expect(p.data).toHaveLength(2);
    expect(p).toMatchObject({ page: 1, pageSize: 2, total: 3, totalPages: 2 });
  });

  it("recusa e-mail repetido com 409 e detalhe no campo", async () => {
    const err = (await api("/users", { method: "POST", body: { name: "Outro", email: "admin@teste.com", password: "123456", role: "RESIDENT" } }).catch((e) => e)) as ApiError;
    expect(err).toMatchObject({ status: 409, details: [{ path: "email" }] });
  });

  it("devolve o detalhe da autorização e cancela só uma vez", async () => {
    const a = await api<Authorization>("/authorizations/a2");
    expect(a).toMatchObject({ id: "a2", status: "ACTIVE", remainingUses: 13 });
    expect(a.createdAt).toBeTruthy();
    await api("/authorizations/a2/cancel", { method: "PATCH", body: {} });
    const again = (await api("/authorizations/a2/cancel", { method: "PATCH", body: {} }).catch((e) => e)) as ApiError;
    expect(again.status).toBe(409);
  });
});

describe("painel simulado", () => {
  it("gera números coerentes entre resumo, gráfico por hora e motivos", async () => {
    const [s, h] = await Promise.all([
      api<DashboardSummary>("/dashboard/summary", { query: { date: "2026-10-20" } }),
      api<HourBucket[]>("/dashboard/accesses-by-hour", { query: { date: "2026-10-20" } }),
    ]);
    expect(h).toHaveLength(24);
    expect(h.reduce((a, x) => a + x.granted, 0)).toBe(s.granted);
    expect(h.reduce((a, x) => a + x.denied, 0)).toBe(s.denied);
    expect(s.byMethod.QR + s.byMethod.NFC + s.byMethod.FACE).toBe(s.granted + s.denied);
    expect(s.topDenialReasons.reduce((a, r) => a + r.count, 0)).toBe(s.denied);
    expect(s.denialRate).toBeCloseTo(s.denied / (s.granted + s.denied));
  });

  it("devolve sempre os mesmos números para o mesmo dia", async () => {
    const a = await api<DashboardSummary>("/dashboard/summary", { query: { date: "2026-10-20" } });
    const b = await api<DashboardSummary>("/dashboard/summary", { query: { date: "2026-10-20" } });
    expect(a).toEqual(b);
  });

  it("recusa data inválida e informa o status do terminal", async () => {
    const err = (await api("/dashboard/summary", { query: { date: "ontem" } }).catch((e) => e)) as ApiError;
    expect(err.status).toBe(400);
    const st = await api<TerminalStatus>("/terminals/tm1/status");
    expect(st).toMatchObject({ id: "tm1", online: true });
    expect(["LOCKED", "UNLOCKED"]).toContain(st.lock);
  });
});
