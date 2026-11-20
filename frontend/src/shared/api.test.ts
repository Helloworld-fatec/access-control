import { describe, expect, it, vi } from "vitest";
import { http, HttpResponse } from "msw";
import { server, API } from "../test/server";
import { api, apiFile, ApiError, filenameFrom, setAccessToken, setUnauthorizedHandler } from "./api";

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

describe("401 que não é de sessão", () => {
  it("não derruba a sessão quando a rota exige a chave do terminal", async () => {
    server.use(http.get(`${API}/terminals/t1/status`, () => HttpResponse.json({ error: { code: "TERMINAL_UNAUTHORIZED", message: "Credencial do terminal obrigatória" } }, { status: 401 })));
    const handler = vi.fn();
    setUnauthorizedHandler(handler);
    setAccessToken("valido");
    const err = (await api("/terminals/t1/status").catch((e) => e)) as ApiError;
    expect(err.status).toBe(401);
    expect(err.code).toBe("TERMINAL_UNAUTHORIZED");
    expect(handler).not.toHaveBeenCalled();
  });

  it("encerra a sessão com token inválido ou expirado", async () => {
    server.use(http.get(`${API}/authorizations`, () => HttpResponse.json({ error: { code: "INVALID_TOKEN", message: "Token inválido ou expirado" } }, { status: 401 })));
    const handler = vi.fn();
    setUnauthorizedHandler(handler);
    setAccessToken("expirado");
    await api("/authorizations").catch(() => undefined);
    expect(handler).toHaveBeenCalledTimes(1);
  });
});

describe("filenameFrom", () => {
  const h = (v?: string) => ({ headers: new Headers(v ? { "Content-Disposition": v } : {}) });
  it("lê o nome entre aspas", () => {
    expect(filenameFrom(h('attachment; filename="historico-acessos-2026-11-19.csv"'), "x.csv")).toBe("historico-acessos-2026-11-19.csv");
  });
  it("usa o padrão quando o cabeçalho não existe", () => {
    expect(filenameFrom(h(), "padrao.csv")).toBe("padrao.csv");
  });
  it("nunca devolve caminhos vindos do servidor", () => {
    expect(filenameFrom(h('attachment; filename="../../etc/passwd"'), "x.csv")).not.toMatch(/[\\/]/);
  });
});

describe("apiFile", () => {
  it("baixa com o token, repassa a query e devolve o nome do servidor", async () => {
    let auth: string | null = null;
    let url = "";
    server.use(
      http.get(`${API}/access-logs/export`, ({ request }) => {
        auth = request.headers.get("authorization");
        url = request.url;
        return new HttpResponse("a;b\r\n", { headers: { "Content-Type": "text/csv", "Content-Disposition": 'attachment; filename="h.csv"' } });
      }),
    );
    setAccessToken("tok");
    const r = await apiFile("/access-logs/export", { query: { result: "DENIED", from: "" } }, "x.csv");
    expect(auth).toBe("Bearer tok");
    expect(url).toContain("result=DENIED");
    expect(url).not.toContain("from=");
    expect(r.filename).toBe("h.csv");
    expect(await r.blob.text()).toBe("a;b\r\n");
  });

  it("transforma erro JSON em ApiError (ex.: arquivo grande demais)", async () => {
    server.use(http.get(`${API}/access-logs/export`, () => HttpResponse.json({ error: { code: "EXPORT_TOO_LARGE", message: "Reduza o período" } }, { status: 413 })));
    await expect(apiFile("/access-logs/export")).rejects.toMatchObject({ status: 413, code: "EXPORT_TOO_LARGE", message: "Reduza o período" });
  });
});
