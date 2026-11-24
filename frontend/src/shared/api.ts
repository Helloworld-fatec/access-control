// Camada única de acesso à API (US-02): token, erros e 401 centralizados.
// Endereço da API: /api por padrão (proxy). Pode ser trocado sem rebuild pelo
// arquivo config.json, servido junto com o front (US-17).
let base = (import.meta.env.VITE_API_URL as string | undefined) || "/api";
export const setApiBase = (b: string) => {
  base = b.replace(/\/+$/, "");
};
export const apiUrl = (path: string) => `${base}${path}`;
export async function loadRuntimeConfig(): Promise<void> {
  try {
    const r = await fetch("/config.json", { cache: "no-store" });
    if (!r.ok) return;
    const c = (await r.json()) as { apiUrl?: unknown };
    if (typeof c.apiUrl === "string" && c.apiUrl.trim()) setApiBase(c.apiUrl.trim());
  } catch {
    /* sem config.json (ou inválido): mantém o padrão */
  }
}

let accessToken: string | null = null;
let sessionVersion = 0;
let unauthorizedHandler: (() => void) | null = null;

export const setAccessToken = (t: string | null) => {
  accessToken = t;
  sessionVersion += 1;
};
export const setUnauthorizedHandler = (fn: (() => void) | null) => {
  unauthorizedHandler = fn;
};

export interface FieldIssue {
  path: string;
  message: string;
}

export class ApiError extends Error {
  status: number;
  code: string;
  details?: FieldIssue[];
  constructor(status: number, code: string, message: string, details?: FieldIssue[]) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

interface Options {
  method?: string;
  query?: Record<string, unknown>;
  body?: unknown;
  form?: FormData;
  authenticated?: boolean;
}

function toQuery(query?: Record<string, unknown>): string {
  if (!query) return "";
  const p = new URLSearchParams();
  for (const [k, v] of Object.entries(query)) {
    if (v !== undefined && v !== null && v !== "") p.set(k, String(v));
  }
  const s = p.toString();
  return s ? `?${s}` : "";
}

// Só estes 401 significam "sessão inválida". Outros (ex.: TERMINAL_UNAUTHORIZED, de rotas que exigem
// a chave do terminal) não podem derrubar o login do administrador.
const SESSION_CODES = new Set(["UNAUTHORIZED", "INVALID_TOKEN", "ERROR"]);

async function raw(path: string, opts: Options): Promise<Response> {
  const headers: Record<string, string> = {};
  const token = opts.authenticated === false ? null : accessToken;
  const requestSession = sessionVersion;
  if (token) headers.Authorization = `Bearer ${token}`;
  let body: BodyInit | undefined;
  if (opts.form) body = opts.form;
  else if (opts.body !== undefined) {
    headers["Content-Type"] = "application/json";
    body = JSON.stringify(opts.body);
  }

  let res: Response;
  try {
    res = await fetch(`${apiUrl(path)}${toQuery(opts.query)}`, {
      method: opts.method ?? "GET",
      headers,
      body,
    });
  } catch {
    throw new ApiError(0, "NETWORK", "Não foi possível conectar ao servidor. Confira se o backend está no ar e se o Wi-Fi está ativo.");
  }

  if (!res.ok) {
    let payload: { error?: { code?: string; message?: string; details?: unknown } } = {};
    try {
      payload = await res.json();
    } catch {
      /* resposta sem corpo JSON */
    }
    const e = payload.error;
    if (res.status === 401 && token && requestSession === sessionVersion && SESSION_CODES.has(e?.code ?? "ERROR")) {
      unauthorizedHandler?.();
    }
    throw new ApiError(
      res.status,
      e?.code ?? "ERROR",
      e?.message ?? `Erro ${res.status} no servidor.`,
      Array.isArray(e?.details) ? (e.details as FieldIssue[]) : undefined,
    );
  }
  return res;
}

export async function api<T>(path: string, opts: Options = {}): Promise<T> {
  const res = await raw(path, opts);
  if (res.status === 204) return undefined as T;
  return (await res.json()) as T;
}

/** Nome do arquivo sugerido pelo servidor (Content-Disposition), ou um padrão. */
export function filenameFrom(res: Pick<Response, "headers">, fallback: string): string {
  const m = /filename\*?=(?:UTF-8'')?"?([^";]+)"?/i.exec(res.headers.get("Content-Disposition") ?? "");
  const name = m ? decodeURIComponent(m[1]).trim() : "";
  // Só o nome: nunca aceitamos caminhos vindos do servidor.
  return name.replace(/[\\/]/g, "_") || fallback;
}

/** Baixa um arquivo gerado pelo servidor (ex.: CSV), com token e tratamento de erros da API. */
export async function apiFile(path: string, opts: Pick<Options, "query"> = {}, fallbackName = "arquivo"): Promise<{ blob: Blob; filename: string }> {
  const res = await raw(path, opts);
  return { blob: await res.blob(), filename: filenameFrom(res, fallbackName) };
}

/** Para a foto: <img> não envia Authorization, então buscamos o arquivo com fetch. */
export async function apiBlob(path: string): Promise<Blob> {
  return (await raw(path, {})).blob();
}
