import { describe, expect, it } from "vitest";
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { http, HttpResponse } from "msw";
import { Route, Routes } from "react-router-dom";
import { renderApp } from "../../test/utils";
import { admin, marina } from "../../test/fixtures";
import { API, server } from "../../test/server";
import LoginPage from "./LoginPage";

const screens = (
  <Routes>
    <Route path="/login" element={<LoginPage />} />
    <Route path="/painel" element={<p>Painel inicial</p>} />
  </Routes>
);

const loginHandler = (user = admin) =>
  http.post(`${API}/login`, async ({ request }) => {
    const body = (await request.json()) as { password: string };
    if (body.password !== "123456") {
      return HttpResponse.json({ error: { code: "INVALID_CREDENTIALS", message: "E-mail ou senha inválidos" } }, { status: 401 });
    }
    return HttpResponse.json({ accessToken: "token", tokenType: "Bearer", expiresIn: "1h", user });
  });

async function fill(email: string, password: string) {
  const user = userEvent.setup();
  if (email) await user.type(screen.getByLabelText(/^E-mail/), email);
  if (password) await user.type(screen.getByLabelText(/^Senha/), password);
  await user.click(screen.getByRole("button", { name: "Entrar" }));
}

describe("LoginPage", () => {
  it("mostra mensagens de validação com os campos vazios", async () => {
    renderApp(screens, "/login");
    await fill("", "");
    expect(await screen.findByText("Informe o e-mail")).toBeInTheDocument();
    expect(screen.getByText("Informe a senha")).toBeInTheDocument();
  });

  it("mostra o erro do backend quando as credenciais são inválidas", async () => {
    server.use(loginHandler());
    renderApp(screens, "/login");
    await fill("admin@teste.com", "errada");
    expect(await screen.findByRole("alert")).toHaveTextContent("E-mail ou senha inválidos");
  });

  it("entra e vai para o painel com credenciais válidas", async () => {
    server.use(loginHandler());
    renderApp(screens, "/login");
    await fill("admin@teste.com", "123456");
    expect(await screen.findByText("Painel inicial")).toBeInTheDocument();
  });

  it("recusa quem não é administrador", async () => {
    server.use(loginHandler(marina));
    renderApp(screens, "/login");
    await fill("marina@teste.com", "123456");
    expect(await screen.findByRole("alert")).toHaveTextContent("Apenas administradores");
    expect(screen.queryByText("Painel inicial")).not.toBeInTheDocument();
  });

  it("em backend antigo, sem POST /login, entra em modo de desenvolvimento", async () => {
    server.use(http.post(`${API}/login`, () => HttpResponse.json({ error: { code: "NOT_FOUND", message: "Rota não encontrada" } }, { status: 404 })));
    renderApp(screens, "/login");
    await fill("admin@teste.com", "qualquer");
    await waitFor(() => expect(screen.getByText("Painel inicial")).toBeInTheDocument());
  });

  it("alterna a visibilidade da senha", async () => {
    renderApp(screens, "/login");
    const user = userEvent.setup();
    const field = screen.getByLabelText(/^Senha/);
    expect(field).toHaveAttribute("type", "password");
    await user.click(screen.getByLabelText("Mostrar senha"));
    expect(field).toHaveAttribute("type", "text");
  });
});
