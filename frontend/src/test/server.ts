import { http, HttpResponse } from "msw";
import { setupServer } from "msw/node";
import { activeAuth, admin, bloco, marina, page, terminal } from "./fixtures";

export const API = "http://localhost/api";

// Respostas padrão; cada teste troca o que precisar com server.use(...).
export const server = setupServer(
  http.get(`${API}/users`, () => HttpResponse.json(page([admin, marina]))),
  http.get(`${API}/locations`, () => HttpResponse.json(page([bloco]))),
  http.get(`${API}/terminals`, () => HttpResponse.json(page([terminal]))),
  http.get(`${API}/authorizations`, () => HttpResponse.json(page([activeAuth]))),
);
