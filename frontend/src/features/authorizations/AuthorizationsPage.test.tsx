import { describe, expect, it } from "vitest";
import { fireEvent, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { http, HttpResponse } from "msw";
import { renderApp } from "../../test/utils";
import { activeAuth } from "../../test/fixtures";
import { API, server } from "../../test/server";
import AuthorizationsPage from "./AuthorizationsPage";

async function openForm() {
  const user = userEvent.setup();
  renderApp(<AuthorizationsPage />);
  await screen.findByText("3 de 5");
  await user.click(screen.getByRole("button", { name: "Nova autorização" }));
  return { user, dialog: screen.getByRole("dialog") };
}

describe("AuthorizationsPage", () => {
  it("lista autorizações com usos restantes e situação", async () => {
    renderApp(<AuthorizationsPage />);
    expect(await screen.findByText("3 de 5")).toBeInTheDocument();
    expect(screen.getByText("Ativa", { selector: "span.badge" })).toBeInTheDocument();
    expect(screen.getByText("08:00 às 18:00")).toBeInTheDocument();
    expect(screen.getByText("01/10/2026 a 31/12/2026")).toBeInTheDocument();
  });

  it("não aceita o formulário vazio e diz o que falta", async () => {
    const { user, dialog } = await openForm();
    await user.click(within(dialog).getByRole("button", { name: "Criar autorização" }));
    expect(await within(dialog).findByText("Escolha a pessoa")).toBeInTheDocument();
    expect(within(dialog).getByText("Escolha o local")).toBeInTheDocument();
    expect(within(dialog).getByText("Informe a data de início")).toBeInTheDocument();
    expect(within(dialog).getByText("Informe a data de término")).toBeInTheDocument();
  });

  it("avisa quando a data de término é anterior à de início", async () => {
    const { user, dialog } = await openForm();
    await user.selectOptions(within(dialog).getByLabelText(/^Pessoa/), "u2");
    await user.selectOptions(within(dialog).getByLabelText(/^Local/), "l1");
    fireEvent.change(within(dialog).getByLabelText(/^Data de início/), { target: { value: "2026-11-10" } });
    fireEvent.change(within(dialog).getByLabelText(/^Data de término/), { target: { value: "2026-11-05" } });
    await user.click(within(dialog).getByRole("button", { name: "Criar autorização" }));
    expect(await within(dialog).findByText("A data de término deve ser igual ou posterior à de início")).toBeInTheDocument();
  });

  it("cria a autorização sem enviar o administrador (vem do token) e avisa o sucesso", async () => {
    let body: Record<string, unknown> | null = null;
    server.use(
      http.post(`${API}/authorizations`, async ({ request }) => {
        body = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json(activeAuth, { status: 201 });
      }),
    );
    const { user, dialog } = await openForm();
    await user.selectOptions(within(dialog).getByLabelText(/^Pessoa/), "u2");
    await user.selectOptions(within(dialog).getByLabelText(/^Local/), "l1");
    fireEvent.change(within(dialog).getByLabelText(/^Data de início/), { target: { value: "2026-11-10" } });
    fireEvent.change(within(dialog).getByLabelText(/^Data de término/), { target: { value: "2026-11-12" } });
    await user.click(within(dialog).getByRole("button", { name: "Criar autorização" }));

    expect(await screen.findByText("Autorização criada.")).toBeInTheDocument();
    expect(body).toMatchObject({ userId: "u2", locationId: "l1", startDate: "2026-11-10", endDate: "2026-11-12", maxUses: null });
    expect(body).not.toHaveProperty("createdById");
  });

  it("pede confirmação antes de cancelar e cancela ao confirmar", async () => {
    let canceled = false;
    server.use(
      http.patch(`${API}/authorizations/a1/cancel`, () => {
        canceled = true;
        return HttpResponse.json({ ...activeAuth, status: "CANCELED" });
      }),
    );
    renderApp(<AuthorizationsPage />);
    const user = userEvent.setup();
    await screen.findByText("3 de 5");

    await user.click(screen.getByRole("button", { name: "Cancelar" }));
    expect(screen.getByText(/não pode ser desfeita/)).toBeInTheDocument();
    expect(canceled).toBe(false);

    await user.click(screen.getByRole("button", { name: "Cancelar autorização" }));
    await waitFor(() => expect(canceled).toBe(true));
    expect(await screen.findByText("Autorização cancelada.")).toBeInTheDocument();
  });
});
