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
