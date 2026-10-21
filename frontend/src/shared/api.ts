// Camada única de acesso à API (US-02): token, erros e 401 centralizados.
const BASE = (import.meta.env.VITE_API_URL as string | undefined) || "/api";

let accessToken: string | null = null;
let unauthorizedHandler: (() => void) | null = null;

export const setAccessToken = (t: string | null) => {
  accessToken = t;
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

async function raw(path: string, opts: Options): Promise<Response> {
  const headers: Record<string, string> = {};
  if (accessToken) headers.Authorization = `Bearer ${accessToken}`;
  let body: BodyInit | undefined;
  if (opts.form) body = opts.form;
  else if (opts.body !== undefined) {
    headers["Content-Type"] = "application/json";
    body = JSON.stringify(opts.body);
  }

  let res: Response;
  try {
    res = await fetch(`${BASE}${path}${toQuery(opts.query)}`, {
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
    if (res.status === 401 && accessToken) unauthorizedHandler?.();
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

/** Para a foto: <img> não envia Authorization, então buscamos o arquivo com fetch. */
export async function apiBlob(path: string): Promise<Blob> {
  return (await raw(path, {})).blob();
}
