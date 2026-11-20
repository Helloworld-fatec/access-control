import { beforeEach, describe, expect, it, vi } from "vitest";
import { fireEvent, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { http, HttpResponse } from "msw";
import { renderApp } from "../../test/utils";
import { API, server } from "../../test/server";
import { page } from "../../test/fixtures";
import AccessLogsPage from "./AccessLogsPage";

const log = { id: "g1", userId: "u2", terminalId: "t1", method: "QR", result: "GRANTED", reason: null, nfcUid: null, createdAt: "2026-11-19T21:13:56.000Z", user: { id: "u2", name: "Marina" }, terminal: { id: "t1", name: "Portaria" } };

let saved: { href: string; name: string }[];

beforeEach(() => {
  saved = [];
  server.use(http.get(`${API}/access-logs`, () => HttpResponse.json(page([log]))));
  URL.createObjectURL = vi.fn(() => "blob:csv");
  URL.revokeObjectURL = vi.fn();
  vi.spyOn(HTMLAnchorElement.prototype, "click").mockImplementation(function (this: HTMLAnchorElement) {
    saved.push({ href: this.href, name: this.download });
  });
});

const csvResponse = () => new HttpResponse("﻿Data e hora;Pessoa\r\n", { headers: { "Content-Type": "text/csv", "Content-Disposition": 'attachment; filename="historico-acessos-2026-11-19.csv"' } });

describe("AccessLogsPage: exportação CSV (US-14)", () => {
  it("avisa que o arquivo tem dados pessoais antes de baixar", async () => {
    const user = userEvent.setup();
    let called = false;
    server.use(http.get(`${API}/access-logs/export`, () => { called = true; return csvResponse(); }));
    renderApp(<AccessLogsPage />);
    await screen.findByText("Marina");
    await user.click(screen.getByRole("button", { name: "Exportar CSV" }));
    const dialog = screen.getByRole("dialog");
    expect(within(dialog).getByText(/contém dados pessoais/)).toBeInTheDocument();
    expect(called).toBe(false); // só baixa depois de confirmar
    await user.click(within(dialog).getByRole("button", { name: "Voltar" }));
    expect(called).toBe(false);
  });

  it("baixa o arquivo do servidor com os filtros atuais, sem paginação", async () => {
    const user = userEvent.setup();
    let query: URLSearchParams | undefined;
    server.use(http.get(`${API}/access-logs/export`, ({ request }) => { query = new URL(request.url).searchParams; return csvResponse(); }));
    renderApp(<AccessLogsPage />);
    await screen.findByText("Marina");
    await user.selectOptions(screen.getByLabelText("Resultado"), "DENIED");
    fireEvent.change(screen.getByLabelText("De"), { target: { value: "2026-11-01" } });
    await user.click(screen.getByRole("button", { name: "Exportar CSV" }));
    await user.click(within(screen.getByRole("dialog")).getByRole("button", { name: "Baixar CSV" }));

    await waitFor(() => expect(saved).toHaveLength(1));
    expect(saved[0].name).toBe("historico-acessos-2026-11-19.csv");
    expect(query?.get("result")).toBe("DENIED");
    expect(query?.get("from")).toBe("2026-11-01");
    expect(query?.has("page")).toBe(false);
    expect(await screen.findByText("Arquivo historico-acessos-2026-11-19.csv baixado.")).toBeInTheDocument();
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  });

  it("mostra o motivo no próprio aviso quando o servidor recusa (ex.: muitos registros)", async () => {
    const user = userEvent.setup();
    server.use(http.get(`${API}/access-logs/export`, () => HttpResponse.json({ error: { code: "EXPORT_TOO_LARGE", message: "Há 80000 registros; o limite é 50000." } }, { status: 413 })));
    renderApp(<AccessLogsPage />);
    await screen.findByText("Marina");
    await user.click(screen.getByRole("button", { name: "Exportar CSV" }));
    await user.click(within(screen.getByRole("dialog")).getByRole("button", { name: "Baixar CSV" }));
    expect(await within(screen.getByRole("dialog")).findByRole("alert")).toHaveTextContent("o limite é 50000");
    expect(saved).toHaveLength(0);
  });

  it("desabilita a exportação quando o período é inválido", async () => {
    renderApp(<AccessLogsPage />);
    await screen.findByText("Marina");
    fireEvent.change(screen.getByLabelText("De"), { target: { value: "2026-11-10" } });
    fireEvent.change(screen.getByLabelText("Até"), { target: { value: "2026-11-01" } });
    expect(screen.getByRole("button", { name: "Exportar CSV" })).toBeDisabled();
  });
});
