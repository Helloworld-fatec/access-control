import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import { screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { installMock } from "./shared/mock";
import { renderApp } from "./test/utils";
import App from "./App";

// Integração: o app inteiro, do login ao painel, contra a API simulada do modo demonstração.
describe("App com API simulada", () => {
  afterEach(() => vi.unstubAllGlobals());

  beforeAll(async () => {
    // A transformação do módulo e do Recharts pelo Vite pode exceder a espera da asserção.
    await import("./features/dashboard/DashboardPage");
    installMock({ live: false });
  });

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

  it("move as visitas para Já saíram e mostra o Pokémon no perfil", async () => {
    vi.stubGlobal("matchMedia", () => ({ matches: true }));
    renderApp(<App />, "/visitas");
    const user = userEvent.setup();
    await user.type(screen.getByLabelText(/^E-mail/), "admin@teste.com");
    await user.type(screen.getByLabelText(/^Senha/), "qualquer");
    await user.click(screen.getByRole("button", { name: "Entrar" }));
    const carlos = await screen.findByRole("row", { name: /Carlos Ferreira/ });
    await user.click(within(carlos).getByRole("button", { name: "Registrar saída" }));
    await user.click(screen.getByRole("button", { name: "Confirmar saída" }));
    const simple = await screen.findByRole("row", { name: /Carlos Ferreira.*Simples/ });
    expect(within(simple).queryByText("Abertura confirmada")).not.toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: /^Dentro/ }));
    const marina = await screen.findByRole("row", { name: /Marina Duarte/ });
    await user.click(within(marina).getByRole("button", { name: "Sortear Pokémon" }));
    const dialog = await screen.findByRole("dialog", { name: "Sortear Pokémon" });
    expect(await within(dialog).findByText(/Bulbasaur/, {}, { timeout: 7000 })).toBeInTheDocument();
    await user.click(within(dialog).getByRole("button", { name: "Pegar Pokémon" }));
    const withPokemon = await screen.findByRole("row", { name: /Marina Duarte.*Com Pokémon/ });
    expect(within(withPokemon).getByText("Abertura confirmada")).toBeInTheDocument();

    await user.click(within(withPokemon).getByRole("link", { name: "Marina Duarte" }));
    expect(await screen.findByRole("heading", { name: "Pokémon obtidos" })).toBeInTheDocument();
    await user.click(await screen.findByRole("link", { name: /Bulbasaur/ }));
    expect(await screen.findByRole("heading", { name: "Bulbasaur" })).toBeInTheDocument();
    expect(screen.getByText("6,9 kg")).toBeInTheDocument();
  }, 15000);
});
