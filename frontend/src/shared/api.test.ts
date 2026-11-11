import { describe, expect, it, vi } from "vitest";
import { http, HttpResponse } from "msw";
import { server, API } from "../test/server";
import { api, ApiError, setAccessToken, setUnauthorizedHandler } from "./api";

describe("cliente HTTP", () => {
  it("envia o token como Bearer e monta a query sem valores vazios", async () => {
    let auth: string | null = null;
    let url = "";
    server.use(
      http.get(`${API}/ping`, ({ request }) => {
        auth = request.headers.get("authorization");
        url = request.url;
        return HttpResponse.json({ ok: true });
      }),
    );
    setAccessToken("abc");
    await api("/ping", { query: { page: 2, search: "", role: undefined, active: false } });
    expect(auth).toBe("Bearer abc");
    expect(new URL(url).searchParams.toString()).toBe("page=2&active=false");
  });

  it("converte o erro do backend em ApiError com código, mensagem e detalhes", async () => {
    server.use(
      http.post(`${API}/users`, () =>
        HttpResponse.json({ error: { code: "VALIDATION_ERROR", message: "Dados inválidos", details: [{ path: "email", message: "E-mail inválido" }] } }, { status: 400 }),
      ),
    );
    const err = await api("/users", { method: "POST", body: {} }).catch((e) => e);
    expect(err).toBeInstanceOf(ApiError);
    expect(err).toMatchObject({ status: 400, code: "VALIDATION_ERROR", message: "Dados inválidos", details: [{ path: "email", message: "E-mail inválido" }] });
  });

  it("chama o tratador de 401 só quando havia sessão", async () => {
    server.use(http.get(`${API}/x`, () => HttpResponse.json({ error: { code: "INVALID_TOKEN", message: "Token inválido ou expirado" } }, { status: 401 })));
    const handler = vi.fn();
    setUnauthorizedHandler(handler);

    await api("/x").catch(() => undefined);
    expect(handler).not.toHaveBeenCalled();

    setAccessToken("expirado");
    await api("/x").catch(() => undefined);
    expect(handler).toHaveBeenCalledTimes(1);
  });

  it("explica falha de rede com status 0", async () => {
    server.use(http.get(`${API}/y`, () => HttpResponse.error()));
    const err = (await api("/y").catch((e) => e)) as ApiError;
    expect(err).toBeInstanceOf(ApiError);
    expect(err.status).toBe(0);
    expect(err.message).toMatch(/conectar ao servidor/);
  });

  it("devolve undefined em respostas 204", async () => {
    server.use(http.delete(`${API}/z`, () => new HttpResponse(null, { status: 204 })));
    await expect(api("/z", { method: "DELETE" })).resolves.toBeUndefined();
  });
});
