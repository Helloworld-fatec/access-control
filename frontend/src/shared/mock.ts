// Modo demonstração (npm run dev:mock): responde a /api/* com dados em memória,
// sem backend. Só é carregado quando VITE_MOCK=true; não vai para a build normal.
import { todayInSaoPaulo } from "./format";
import type { AccessLog, Location, Role, User } from "./types";

interface MUser extends User { face: boolean; tags: { id: string; uid: string; active: boolean; createdAt: string }[] }
interface MTerminal { id: string; name: string; locationId: string; latitude: number; longitude: number; online: boolean; lastPresenceAt: string | null; lastSeenAt: string | null }
interface MAuth { id: string; userId: string; locationId: string; startDate: string; endDate: string; startTime: string; endTime: string; maxUses: number | null; usedCount: number; canceled: boolean }
interface MLog { id: string; userId: string | null; terminalId: string; method: AccessLog["method"]; result: AccessLog["result"]; reason: string | null; nfcUid: string | null; createdAt: string }

class HttpErr {
  status: number; code: string; message: string; details?: { path: string; message: string }[];
  constructor(status: number, code: string, message: string, details?: { path: string; message: string }[]) {
    this.status = status; this.code = code; this.message = message; this.details = details;
  }
}
const bad = (path: string, message: string) => new HttpErr(400, "VALIDATION_ERROR", "Dados inválidos", [{ path, message }]);

const id = () => Math.random().toString(36).slice(2, 10) + Date.now().toString(36);
const now = Date.now();
const iso = (offsetMin: number) => new Date(now - offsetMin * 60_000).toISOString();
const day = (offset: number) => new Date(now + offset * 86_400_000).toISOString().slice(0, 10);

const users: MUser[] = [
  ["Administrador", "admin@teste.com", "ADMIN", "000.000.000-00"],
  ["Marina Duarte", "marina@teste.com", "RESIDENT", "111.222.333-44"],
  ["Carlos Ferreira", "carlos@teste.com", "RESIDENT", "222.333.444-55"],
  ["Beatriz Nogueira", "beatriz@teste.com", "RESIDENT", null],
  ["Paulo Visitante", "paulo@teste.com", "VISITOR", null],
].map(([name, email, role, document], i) => ({
  id: `u${i + 1}`, name: name as string, email: email as string, role: role as Role, document: document as string | null,
  phone: i === 1 ? "(11) 91234-5678" : null, active: i !== 3, createdAt: iso(60 * 24 * (10 - i)), face: i === 1,
  tags: i === 2 ? [{ id: "t1", uid: "04A32F1B", active: true, createdAt: iso(5000) }] : [],
}));
const locations: Location[] = [
  { id: "l1", building: "Bloco A", entrance: "Portaria principal", door: null, turnstile: "Catraca 1", description: "Entrada de moradores" },
  { id: "l2", building: "Bloco B", entrance: null, door: "Sala de reuniões", turnstile: null, description: null },
];
const terminals: MTerminal[] = [
  { id: "tm1", name: "Portaria A", locationId: "l1", latitude: -23.5505, longitude: -46.6333, online: true, lastPresenceAt: iso(1), lastSeenAt: iso(1) },
  { id: "tm2", name: "Sala B", locationId: "l2", latitude: -23.5512, longitude: -46.6341, online: false, lastPresenceAt: iso(600), lastSeenAt: iso(600) },
];
const auths: MAuth[] = [
  { id: "a1", userId: "u2", locationId: "l1", startDate: day(-30), endDate: day(60), startTime: "06:00", endTime: "23:00", maxUses: null, usedCount: 12, canceled: false },
  { id: "a2", userId: "u3", locationId: "l1", startDate: day(-5), endDate: day(10), startTime: "08:00", endTime: "18:00", maxUses: 20, usedCount: 7, canceled: false },
  { id: "a3", userId: "u5", locationId: "l2", startDate: day(-40), endDate: day(-20), startTime: "09:00", endTime: "12:00", maxUses: 3, usedCount: 3, canceled: false },
  { id: "a4", userId: "u3", locationId: "l2", startDate: day(-3), endDate: day(3), startTime: "09:00", endTime: "17:00", maxUses: null, usedCount: 0, canceled: true },
];
const REASONS = ["INVALID_CREDENTIAL", "OUTSIDE_SCHEDULE", "NO_AUTHORIZATION", "USES_EXHAUSTED", "FACE_LOW_CONFIDENCE"];
const logs: MLog[] = Array.from({ length: 42 }, (_, i) => {
  const granted = i % 3 !== 0;
  const method = (["QR", "NFC", "FACE"] as const)[i % 3];
  return {
    id: `g${i}`, userId: i % 7 === 6 ? null : ["u2", "u3", "u5"][i % 3], terminalId: i % 4 === 3 ? "tm2" : "tm1", method,
    result: granted ? "GRANTED" : "DENIED", reason: granted ? null : REASONS[i % REASONS.length],
    nfcUid: i % 7 === 6 ? "9F8E7D6C" : null, createdAt: iso(i * 95 + 3),
  };
});

const clean = (v: unknown) => (typeof v === "string" && v.trim() !== "" ? v.trim() : null);
const page = <T,>(items: T[], q: URLSearchParams) => {
  const p = Math.max(Number(q.get("page")) || 1, 1);
  const size = Math.min(Math.max(Number(q.get("pageSize")) || 20, 1), 100);
  return { data: items.slice((p - 1) * size, p * size), page: p, pageSize: size, total: items.length, totalPages: Math.max(Math.ceil(items.length / size), 1) };
};
const publicUser = (u: MUser): User => ({ id: u.id, name: u.name, document: u.document, email: u.email, phone: u.phone, role: u.role, active: u.active, createdAt: u.createdAt });
const find = <T extends { id: string }>(list: T[], key: string, label: string) => {
  const x = list.find((i) => i.id === key);
  if (!x) throw new HttpErr(404, "NOT_FOUND", `${label} não encontrado.`);
  return x;
};
const authOut = (a: MAuth) => {
  const status = a.canceled ? "CANCELED" : a.endDate < day(0) ? "EXPIRED" : "ACTIVE";
  const u = users.find((x) => x.id === a.userId);
  return {
    ...a, status, remainingUses: a.maxUses == null ? null : Math.max(a.maxUses - a.usedCount, 0),
    location: locations.find((l) => l.id === a.locationId), user: u ? { id: u.id, name: u.name } : undefined,
  };
};
const termOut = (t: MTerminal) => ({ ...t, location: locations.find((l) => l.id === t.locationId) });
// ---- Painel: dados de demonstração, gerados de forma estável a partir da data ----
const hashStr = (s: string) => {
  let h = 2166136261;
  for (const c of s) h = Math.imul(h ^ c.charCodeAt(0), 16777619);
  return h >>> 0;
};
const rng = (seed: number) => () => {
  seed = (seed + 0x6d2b79f5) | 0;
  let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};
const HOUR_WEIGHT = [0, 0, 0, 0, 0, 1, 3, 8, 14, 10, 7, 6, 9, 8, 6, 6, 7, 12, 15, 11, 6, 3, 1, 0];
const currentHourSP = () =>
  Number(new Intl.DateTimeFormat("en-GB", { hour: "2-digit", hourCycle: "h23", timeZone: "America/Sao_Paulo" }).format(new Date()));

function hourly(date: string) {
  const r = rng(hashStr(date));
  const limit = date === todayInSaoPaulo() ? currentHourSP() : 23;
  return HOUR_WEIGHT.map((w, hour) => {
    const total = hour > limit ? 0 : Math.round(w * (0.8 + r() * 0.6));
    const denied = Math.round(total * (0.08 + r() * 0.15));
    return { hour, granted: total - denied, denied };
  });
}
function split(total: number, weights: number[]) {
  const parts = weights.map((w) => Math.floor(total * w));
  parts[0] += total - parts.reduce((a, b) => a + b, 0);
  return parts;
}
function summarize(date: string, hours: ReturnType<typeof hourly>) {
  const granted = hours.reduce((a, h) => a + h.granted, 0);
  const denied = hours.reduce((a, h) => a + h.denied, 0);
  const total = granted + denied;
  const [qr, nfc, face] = split(total, [0.45, 0.3, 0.25]);
  const reasons = split(denied, [0.35, 0.25, 0.2, 0.12, 0.08]);
  const list = auths.map(authOut);
  return {
    date, granted, denied, denialRate: total ? denied / total : 0,
    byMethod: { QR: qr, NFC: nfc, FACE: face },
    authorizations: {
      active: list.filter((a) => a.status === "ACTIVE").length,
      expiringSoon: list.filter((a) => a.status === "ACTIVE" && a.endDate <= day(7)).length,
      canceled: list.filter((a) => a.status === "CANCELED").length,
    },
    topDenialReasons: REASONS.map((reason, i) => ({ reason, count: reasons[i] })).filter((x) => x.count > 0).sort((a, b) => b.count - a.count),
  };
}
const terminalStatus = (t: MTerminal) => {
  const last = t.lastPresenceAt ? new Date(t.lastPresenceAt).getTime() : 0;
  const recent = Date.now() - last <= 5000;
  const lastLog = logs.find((l) => l.terminalId === t.id);
  const opened = Boolean(lastLog && lastLog.result === "GRANTED" && Date.now() - new Date(lastLog.createdAt).getTime() <= 5000);
  return { id: t.id, online: t.online, presence: recent, presenceActive: recent, lastPresenceAt: t.lastPresenceAt, lastSeenAt: t.lastSeenAt, lock: opened ? "UNLOCKED" : "LOCKED" };
};

const need = (b: Record<string, unknown>, field: string, msg: string) => {
  if (typeof b[field] !== "string" || !(b[field] as string).trim()) throw bad(field, msg);
};

function route(method: string, path: string[], q: URLSearchParams, b: Record<string, unknown>): { status: number; body?: unknown } {
  const [res, rid, sub, sid] = path;
  const ok = (body: unknown, status = 200) => ({ status, body });
  const none = { status: 204 };

  if (res === "login" && method === "POST") {
    const u = users.find((x) => x.email === String(b.email ?? "").trim().toLowerCase() && x.active && x.role === "ADMIN");
    if (!u) throw new HttpErr(401, "INVALID_CREDENTIALS", "E-mail ou senha incorretos. (Demonstração: use admin@teste.com)");
    return ok({ accessToken: "mock-token", tokenType: "Bearer", expiresIn: "1h", user: publicUser(u) });
  }

  if (res === "users") {
    if (!rid) {
      if (method === "GET") {
        const s = (q.get("search") ?? "").toLowerCase();
        const list = users.filter((u) =>
          (!s || u.name.toLowerCase().includes(s) || (u.document ?? "").includes(s)) &&
          (!q.get("role") || u.role === q.get("role")) && (!q.get("active") || String(u.active) === q.get("active")));
        return ok(page(list.sort((a, c) => a.name.localeCompare(c.name)).map(publicUser), q));
      }
      need(b, "name", "Nome muito curto"); need(b, "email", "E-mail inválido");
      if (String(b.password ?? "").length < 6) throw bad("password", "Senha deve ter ao menos 6 caracteres");
      if (users.some((u) => u.email === String(b.email).trim().toLowerCase())) throw new HttpErr(409, "CONFLICT", "Já existe um usuário com esse e-mail.", [{ path: "email", message: "Já existe um usuário com esse e-mail." }]);
      const u: MUser = { id: id(), name: String(b.name).trim(), email: String(b.email).trim().toLowerCase(), role: b.role as Role, document: clean(b.document), phone: clean(b.phone), active: true, createdAt: new Date().toISOString(), face: false, tags: [] };
      users.push(u);
      return ok(publicUser(u), 201);
    }
    const u = find(users, rid, "Usuário");
    if (!sub) {
      if (method === "GET") return ok({ ...publicUser(u), hasFace: u.face, hasPhoto: false, nfcTags: u.tags.map((t) => ({ ...t, userId: u.id })) });
      if (b.email && users.some((x) => x.id !== u.id && x.email === String(b.email).trim().toLowerCase())) throw new HttpErr(409, "CONFLICT", "Já existe um usuário com esse e-mail.", [{ path: "email", message: "Já existe um usuário com esse e-mail." }]);
      if (b.name) u.name = String(b.name).trim();
      if (b.email) u.email = String(b.email).trim().toLowerCase();
      if (b.role) u.role = b.role as Role;
      u.document = clean(b.document); u.phone = clean(b.phone);
      return ok(publicUser(u));
    }
    if (sub === "status") { u.active = Boolean(b.active); return ok(publicUser(u)); }
    if (sub === "face") { u.face = false; return none; }
    if (sub === "tags") {
      if (method === "DELETE") { u.tags = u.tags.filter((t) => t.id !== sid); return none; }
      const uidv = String(b.uid ?? "").replace(/[\s:-]/g, "").toUpperCase();
      if (!/^[0-9A-F]{8,20}$/.test(uidv)) throw bad("uid", "UID deve ser hexadecimal, com 8 a 20 caracteres");
      if (users.some((x) => x.tags.some((t) => t.uid === uidv))) throw new HttpErr(409, "CONFLICT", "Essa tag já está vinculada a um usuário.");
      const t = { id: id(), uid: uidv, active: true, createdAt: new Date().toISOString() };
      u.tags.push(t);
      return ok({ ...t, userId: u.id }, 201);
    }
    if (sub === "photo") throw new HttpErr(404, "NOT_FOUND", "Sem foto.");
  }

  if (res === "locations") {
    if (!rid) {
      if (method === "GET") {
        const s = (q.get("search") ?? "").toLowerCase();
        return ok(page(locations.filter((l) => !s || [l.building, l.entrance, l.door, l.turnstile].join(" ").toLowerCase().includes(s)), q));
      }
      need(b, "building", "Informe o edifício");
      const l: Location = { id: id(), building: String(b.building).trim(), entrance: clean(b.entrance), door: clean(b.door), turnstile: clean(b.turnstile), description: clean(b.description) };
      locations.push(l);
      return ok(l, 201);
    }
    const l = find(locations, rid, "Local");
    if (method === "DELETE") {
      if (terminals.some((t) => t.locationId === l.id) || auths.some((a) => a.locationId === l.id)) throw new HttpErr(409, "CONFLICT", "Não é possível excluir: há terminais ou autorizações vinculados a este local.");
      locations.splice(locations.indexOf(l), 1);
      return none;
    }
    need(b, "building", "Informe o edifício");
    Object.assign(l, { building: String(b.building).trim(), entrance: clean(b.entrance), door: clean(b.door), turnstile: clean(b.turnstile), description: clean(b.description) });
    return ok(l);
  }

  if (res === "terminals") {
    if (!rid) {
      if (method === "GET") return ok(page(terminals.filter((t) => !q.get("locationId") || t.locationId === q.get("locationId")).map(termOut), q));
      need(b, "name", "Informe o nome"); need(b, "locationId", "Escolha o local");
      const t: MTerminal = { id: id(), name: String(b.name).trim(), locationId: String(b.locationId), latitude: Number(b.latitude), longitude: Number(b.longitude), online: false, lastPresenceAt: null, lastSeenAt: null };
      terminals.push(t);
      return ok({ ...termOut(t), apiKey: `demo_${id()}${id()}` }, 201);
    }
    const t = find(terminals, rid, "Terminal");
    if (sub === "status") return ok(terminalStatus(t));
    if (method === "DELETE") { terminals.splice(terminals.indexOf(t), 1); return none; }
    if (b.name) t.name = String(b.name).trim();
    if (b.locationId) t.locationId = String(b.locationId);
    if (b.latitude !== undefined) t.latitude = Number(b.latitude);
    if (b.longitude !== undefined) t.longitude = Number(b.longitude);
    return ok(termOut(t));
  }

  if (res === "authorizations") {
    if (!rid) {
      if (method === "GET") {
        const from = q.get("from"), to = q.get("to");
        const list = auths.map(authOut).filter((a) =>
          (!q.get("userId") || a.userId === q.get("userId")) && (!q.get("locationId") || a.locationId === q.get("locationId")) &&
          (!q.get("status") || a.status === q.get("status")) && (!from || a.endDate >= from) && (!to || a.startDate <= to));
        return ok(page(list, q));
      }
      for (const f of ["userId", "locationId", "startDate", "endDate", "startTime", "endTime"]) need(b, f, "Campo obrigatório");
      if (String(b.endDate) < String(b.startDate)) throw bad("endDate", "A data de término deve ser igual ou posterior à de início");
      if (String(b.endTime) <= String(b.startTime)) throw bad("endTime", "O horário de término deve ser posterior ao de início");
      const a: MAuth = { id: id(), userId: String(b.userId), locationId: String(b.locationId), startDate: String(b.startDate), endDate: String(b.endDate), startTime: String(b.startTime), endTime: String(b.endTime), maxUses: b.maxUses ? Number(b.maxUses) : null, usedCount: 0, canceled: false };
      auths.unshift(a);
      return ok(authOut(a), 201);
    }
    const a = find(auths, rid, "Autorização");
    if (!sub && method === "GET") return ok({ ...authOut(a), createdAt: iso(60 * 24 * 7), canceledAt: a.canceled ? iso(30) : null });
    if (sub === "cancel") {
      if (a.canceled) throw new HttpErr(409, "CONFLICT", "Esta autorização já foi cancelada.");
      a.canceled = true;
      return ok(authOut(a));
    }
  }

  if (res === "dashboard" && (rid === "summary" || rid === "accesses-by-hour")) {
    const date = q.get("date") || todayInSaoPaulo();
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) throw bad("date", "Data inválida (use AAAA-MM-DD)");
    const hours = hourly(date);
    return ok(rid === "summary" ? summarize(date, hours) : hours);
  }

  if (res === "access-logs" && !rid) {
    const from = q.get("from"), to = q.get("to");
    const list = logs.filter((l) =>
      (!q.get("userId") || l.userId === q.get("userId")) && (!q.get("terminalId") || l.terminalId === q.get("terminalId")) &&
      (!q.get("method") || l.method === q.get("method")) && (!q.get("result") || l.result === q.get("result")) &&
      (!from || l.createdAt.slice(0, 10) >= from) && (!to || l.createdAt.slice(0, 10) <= to));
    return ok(page(list.map((l) => {
      const u = users.find((x) => x.id === l.userId);
      const t = terminals.find((x) => x.id === l.terminalId);
      return { ...l, user: u ? { id: u.id, name: u.name } : null, terminal: t ? { id: t.id, name: t.name } : undefined };
    }), q));
  }

  throw new HttpErr(404, "NOT_FOUND", `Rota não encontrada: ${method} /${path.join("/")}`);
}

/** Gera um acesso novo de tempos em tempos, para o painel mostrar a atualização automática. */
function startLiveEvents() {
  const people = ["u2", "u3", "u5"];
  const timer = setInterval(() => {
    const n = Math.random();
    const granted = n < 0.75;
    const t = terminals[0];
    const nowIso = new Date().toISOString();
    logs.unshift({
      id: id(), userId: people[Math.floor(Math.random() * people.length)], terminalId: t.id,
      method: (["QR", "NFC", "FACE"] as const)[Math.floor(Math.random() * 3)], result: granted ? "GRANTED" : "DENIED",
      reason: granted ? null : REASONS[Math.floor(Math.random() * REASONS.length)], nfcUid: null, createdAt: nowIso,
    });
    t.lastPresenceAt = nowIso;
    t.lastSeenAt = nowIso;
  }, 8000);
  return () => clearInterval(timer);
}

export function installMock(options: { live?: boolean } = {}) {
  if (options.live ?? true) startLiveEvents();
  const realFetch = window.fetch.bind(window);
  window.fetch = async (input, init) => {
    const href = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
    const url = new URL(href, window.location.origin);
    if (!url.pathname.startsWith("/api/")) return realFetch(input, init);
    await new Promise((r) => setTimeout(r, 150));
    const body = typeof init?.body === "string" ? (JSON.parse(init.body) as Record<string, unknown>) : {};
    try {
      const r = route((init?.method ?? "GET").toUpperCase(), url.pathname.slice(5).split("/").filter(Boolean), url.searchParams, body);
      return new Response(r.status === 204 ? null : JSON.stringify(r.body), { status: r.status, headers: { "Content-Type": "application/json" } });
    } catch (e) {
      if (!(e instanceof HttpErr)) throw e;
      return new Response(JSON.stringify({ error: { code: e.code, message: e.message, details: e.details } }), { status: e.status, headers: { "Content-Type": "application/json" } });
    }
  };
  console.info("[demo] Modo demonstração ativo: a API é simulada no navegador.");
}
