import type { AuthStatus, Location, Method, Role } from "./types";

const TZ = "America/Sao_Paulo";

export const formatDateTime = (iso: string | null) =>
  iso
    ? new Intl.DateTimeFormat("pt-BR", { dateStyle: "short", timeStyle: "medium", timeZone: TZ }).format(new Date(iso))
    : "—";

/** "2026-10-17" -> "17/10/2026" sem passar por Date (evita deslocar o dia pelo fuso). */
export const formatDateOnly = (d: string) => d.split("-").reverse().join("/");

export const locationLabel = (l?: Location | null) =>
  l ? [l.building, l.entrance, l.door, l.turnstile].filter(Boolean).join(" / ") : "—";

export const ROLE_LABEL: Record<Role, string> = { ADMIN: "Administrador", RESIDENT: "Condômino", VISITOR: "Visitante" };
export const STATUS_LABEL: Record<AuthStatus, string> = { ACTIVE: "Ativa", CANCELED: "Cancelada", EXPIRED: "Expirada" };
export const METHOD_LABEL: Record<Method, string> = { QR: "QR Code", NFC: "Tag NFC", FACE: "Facial" };

export const REASON_LABEL: Record<string, string> = {
  INVALID_CREDENTIAL: "Credencial inválida",
  EXPIRED_CREDENTIAL: "Credencial vencida",
  REPLAYED_CREDENTIAL: "Credencial já utilizada",
  USER_INACTIVE: "Usuário inativo",
  NO_AUTHORIZATION: "Sem autorização para o local",
  AUTHORIZATION_CANCELED: "Autorização cancelada",
  OUTSIDE_PERIOD: "Fora do período",
  OUTSIDE_SCHEDULE: "Fora do horário",
  USES_EXHAUSTED: "Usos esgotados",
  TOO_FAR: "Longe do terminal",
  FACE_LOW_CONFIDENCE: "Rosto com baixa confiança",
  TERMINAL_OFFLINE: "Terminal offline",
};

/** UID de tag: hexadecimal em maiúsculas, sem separadores (mesmo padrão do backend e dos apps). */
export const normalizeUid = (v: string) => v.replace(/[\s:-]/g, "").toUpperCase();

/** Mostra só os 3 últimos caracteres alfanuméricos do documento: 111.222.333-44 -> •••.•••.••3-44 */
export function maskDocument(doc: string): string {
  let keep = 3;
  const out: string[] = [];
  for (let i = doc.length - 1; i >= 0; i--) {
    const c = doc[i];
    if (!/[0-9A-Za-z]/.test(c)) out.push(c);
    else if (keep > 0) {
      out.push(c);
      keep--;
    } else out.push("•");
  }
  return out.reverse().join("");
}

/** Data de hoje (AAAA-MM-DD) em America/Sao_Paulo. */
export const todayInSaoPaulo = () => new Intl.DateTimeFormat("en-CA", { timeZone: TZ }).format(new Date());

/** "há 12 s", "há 3 min" ou a data completa, para o monitoramento. */
export function timeAgo(iso: string | null, now = Date.now()): string {
  if (!iso) return "Nunca";
  const s = Math.max(Math.round((now - new Date(iso).getTime()) / 1000), 0);
  if (s < 60) return `há ${s} s`;
  if (s < 3600) return `há ${Math.floor(s / 60)} min`;
  return formatDateTime(iso);
}
