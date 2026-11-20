import { describe, expect, it } from "vitest";
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { http, HttpResponse } from "msw";
import { renderApp } from "../../test/utils";
import { admin, marina, page } from "../../test/fixtures";
import { API, server } from "../../test/server";
import UsersPage from "./UsersPage";

describe("UsersPage", () => {
  it("lista os usuários com perfil e situação em português", async () => {
    renderApp(<UsersPage />);
    expect(await screen.findByRole("link", { name: "Marina Duarte" })).toHaveAttribute("href", "/usuarios/u2");
    expect(screen.getByText("Condômino", { selector: "td" })).toBeInTheDocument();
    expect(screen.getByText("Administrador", { selector: "td" })).toBeInTheDocument();
    expect(screen.getAllByText("Ativo")).toHaveLength(2);
  });

  it("envia o filtro de perfil e a busca ao servidor", async () => {
    const urls: URL[] = [];
    server.use(
      http.get(`${API}/users`, ({ request }) => {
        urls.push(new URL(request.url));
        return HttpResponse.json(page([admin]));
      }),
    );
    renderApp(<UsersPage />);
    const user = userEvent.setup();
    await screen.findByText("Administrador", { selector: "td" });

    await user.selectOptions(screen.getByLabelText("Perfil"), "ADMIN");
    await waitFor(() => expect(urls.some((u) => u.searchParams.get("role") === "ADMIN")).toBe(true));

    await user.type(screen.getByLabelText(/Buscar/), "ana");
    await waitFor(() => expect(urls.some((u) => u.searchParams.get("search") === "ana")).toBe(true));
    expect(urls.every((u) => u.searchParams.get("pageSize") === "20")).toBe(true);
  });

  it("mostra o estado vazio", async () => {
    server.use(http.get(`${API}/users`, () => HttpResponse.json(page([]))));
    renderApp(<UsersPage />);
    expect(await screen.findByText(/Nenhum usuário encontrado/)).toBeInTheDocument();
  });

  it("mostra o erro e permite tentar de novo", async () => {
    let calls = 0;
    server.use(
      http.get(`${API}/users`, () => {
        calls++;
        return calls === 1
          ? HttpResponse.json({ error: { code: "INTERNAL_ERROR", message: "Erro interno do servidor" } }, { status: 500 })
          : HttpResponse.json(page([marina]));
      }),
    );
    renderApp(<UsersPage />);
    const user = userEvent.setup();
    expect(await screen.findByRole("alert")).toHaveTextContent("Erro interno do servidor");
    await user.click(screen.getByRole("button", { name: "Tentar de novo" }));
    expect(await screen.findByRole("link", { name: "Marina Duarte" })).toBeInTheDocument();
  });
});
