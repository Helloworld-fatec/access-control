import { beforeAll, describe, expect, it } from "vitest";
import { screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { installMock } from "./shared/mock";
import { renderApp } from "./test/utils";
import App from "./App";

// Integração: o app inteiro, do login ao painel, contra a API simulada do modo demonstração.
describe("App com API simulada", () => {
  beforeAll(() => installMock({ live: false }));

  it("entra, vê o painel com dados de exemplo e navega pelo menu", async () => {
    renderApp(<App />, "/login");
    const user = userEvent.setup();
    await user.type(screen.getByLabelText(/^E-mail/), "admin@teste.com");
    await user.type(screen.getByLabelText(/^Senha/), "qualquer");
    await user.click(screen.getByRole("button", { name: "Entrar" }));

    expect(await screen.findByRole("heading", { name: "Painel" })).toBeInTheDocument();
    expect(await screen.findByText("Taxa de negação")).toBeInTheDocument();
    const card = await screen.findByRole("article", { name: "Terminal Portaria A" });
    expect(await within(card).findByText("Online")).toBeInTheDocument();

    await user.click(screen.getByRole("link", { name: "Usuários" }));
    expect(await screen.findByRole("link", { name: "Marina Duarte" })).toBeInTheDocument();
  });
});
