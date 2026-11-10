import { describe, expect, it } from "vitest";
import { screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { http, HttpResponse } from "msw";
import { renderApp } from "../../test/utils";
import { API, server } from "../../test/server";
import type { AccessLog, DashboardSummary, HourBucket, TerminalStatus } from "../../shared/types";
import { page } from "../../test/fixtures";
import DashboardPage from "./DashboardPage";

const summary: DashboardSummary = {
  date: "2026-11-09", granted: 120, denied: 30, denialRate: 0.2,
  byMethod: { QR: 70, NFC: 50, FACE: 30 },
  authorizations: { active: 8, expiringSoon: 2, canceled: 1 },
  topDenialReasons: [{ reason: "OUTSIDE_SCHEDULE", count: 18 }, { reason: "USES_EXHAUSTED", count: 12 }],
};
const hours: HourBucket[] = Array.from({ length: 24 }, (_, hour) => ({ hour, granted: hour === 8 ? 40 : 0, denied: hour === 8 ? 5 : 0 }));
const status: TerminalStatus = { id: "t1", online: true, presenceActive: true, lastPresenceAt: new Date().toISOString(), lastSeenAt: new Date().toISOString(), lock: "UNLOCKED" };
const log: AccessLog = {
  id: "g1", userId: "u2", terminalId: "t1", method: "FACE", result: "DENIED", reason: "FACE_LOW_CONFIDENCE", nfcUid: null,
  createdAt: "2026-11-09T15:00:00.000Z", user: { id: "u2", name: "Marina Duarte" }, terminal: { id: "t1", name: "Portaria A" },
};

const useDashboard = () =>
  server.use(
    http.get(`${API}/dashboard/summary`, () => HttpResponse.json(summary)),
    http.get(`${API}/dashboard/accesses-by-hour`, () => HttpResponse.json(hours)),
    http.get(`${API}/terminals/t1/status`, () => HttpResponse.json(status)),
    http.get(`${API}/access-logs`, () => HttpResponse.json(page([log]))),
  );

describe("DashboardPage", () => {
  it("mostra liberados, negados e a taxa de negação do dia", async () => {
    useDashboard();
    renderApp(<DashboardPage />);
    const granted = await screen.findByText("Acessos liberados");
    expect(granted.previousElementSibling).toHaveTextContent("120");
    expect(screen.getByText("Acessos negados").previousElementSibling).toHaveTextContent("30");
    expect(screen.getByText("20,0%")).toBeInTheDocument();
    expect(screen.getByText("150 tentativas no dia")).toBeInTheDocument();
  });

  it("mostra autorizações, métodos e motivos de negação em português", async () => {
    useDashboard();
    renderApp(<DashboardPage />);
    const reasons = await screen.findByRole("region", { name: "Principais motivos de negação" });
    expect(within(reasons).getByText("Fora do horário")).toBeInTheDocument();
    expect(within(reasons).getByText("18")).toBeInTheDocument();
    const methods = screen.getByRole("region", { name: "Acessos por método" });
    expect(within(methods).getByText("QR Code")).toBeInTheDocument();
    expect(within(methods).getByText("70")).toBeInTheDocument();
    expect(screen.getByText("Expiram em 7 dias")).toBeInTheDocument();
  });

  it("oferece os dados do gráfico em tabela", async () => {
    useDashboard();
    renderApp(<DashboardPage />);
    await screen.findByText("Ver os dados em tabela");
    const row = screen.getByRole("row", { name: /08h/ });
    expect(row).toHaveTextContent("40");
    expect(row).toHaveTextContent("5");
  });

  it("mostra o status de cada terminal, com presença e trava", async () => {
    useDashboard();
    renderApp(<DashboardPage />);
    const card = await screen.findByRole("article", { name: "Terminal Portaria A" });
    expect(await within(card).findByText("Online")).toBeInTheDocument();
    expect(within(card).getByText("Pessoa detectada")).toBeInTheDocument();
    expect(within(card).getByText("Destrancada")).toBeInTheDocument();
  });

  it("lista os últimos acessos", async () => {
    useDashboard();
    renderApp(<DashboardPage />);
    const recent = await screen.findByRole("region", { name: "Últimos acessos" });
    expect(await within(recent).findByText("Marina Duarte")).toBeInTheDocument();
    expect(within(recent).getByText("Negado")).toBeInTheDocument();
    expect(within(recent).getByText("Rosto com baixa confiança")).toBeInTheDocument();
  });

  it("explica que o backend ainda não tem os indicadores (404)", async () => {
    server.use(
      http.get(`${API}/dashboard/summary`, () => HttpResponse.json({ error: { code: "NOT_FOUND", message: "Rota não encontrada" } }, { status: 404 })),
      http.get(`${API}/dashboard/accesses-by-hour`, () => HttpResponse.json({ error: { code: "NOT_FOUND", message: "Rota não encontrada" } }, { status: 404 })),
      http.get(`${API}/terminals/t1/status`, () => HttpResponse.json(status)),
      http.get(`${API}/access-logs`, () => HttpResponse.json(page([]))),
    );
    renderApp(<DashboardPage />);
    const alerts = await screen.findAllByRole("alert");
    expect(alerts[0]).toHaveTextContent("ainda não existe no backend");
    expect(alerts[0]).toHaveTextContent("npm run dev:mock");
  });

  it("avisa que o status do terminal só vale para o próprio terminal (403)", async () => {
    server.use(
      http.get(`${API}/dashboard/summary`, () => HttpResponse.json(summary)),
      http.get(`${API}/dashboard/accesses-by-hour`, () => HttpResponse.json(hours)),
      http.get(`${API}/terminals/t1/status`, () => HttpResponse.json({ error: { code: "UNAUTHORIZED", message: "Chave do terminal inválida" } }, { status: 401 })),
      http.get(`${API}/access-logs`, () => HttpResponse.json(page([]))),
    );
    renderApp(<DashboardPage />);
    const card = await screen.findByRole("article", { name: "Terminal Portaria A" });
    expect(await within(card).findByRole("alert")).toHaveTextContent("exige a chave do terminal");
  });

  it("permite pausar a atualização automática", async () => {
    useDashboard();
    renderApp(<DashboardPage />);
    const user = userEvent.setup();
    expect(await screen.findByText("Atualiza a cada 5 segundos.")).toBeInTheDocument();
    await user.click(screen.getByLabelText("Pausar atualização automática"));
    expect(screen.getByText("Atualização automática pausada.")).toBeInTheDocument();
  });
});
