// Espelha as respostas do backend (backend/src/models/*.model.ts).
export type Role = "ADMIN" | "RESIDENT" | "VISITOR";
export type AuthStatus = "ACTIVE" | "CANCELED" | "EXPIRED";
export type Method = "QR" | "NFC" | "FACE";
export type AccessResult = "GRANTED" | "DENIED";

export interface Paginated<T> {
  data: T[];
  page: number;
  pageSize: number;
  total: number;
  totalPages: number;
}

export interface User {
  id: string;
  name: string;
  document: string | null;
  email: string;
  phone: string | null;
  role: Role;
  active: boolean;
  createdAt: string;
}
export interface NfcTag {
  id: string;
  uid: string;
  userId: string;
  active: boolean;
  createdAt: string;
}
export interface UserDetail extends User {
  hasFace: boolean;
  hasPhoto: boolean;
  nfcTags: NfcTag[];
}

export interface Location {
  id: string;
  building: string;
  entrance: string | null;
  door: string | null;
  turnstile: string | null;
  description: string | null;
}
export interface Terminal {
  id: string;
  name: string;
  locationId: string;
  latitude: number;
  longitude: number;
  online: boolean;
  lastPresenceAt: string | null;
  lastSeenAt: string | null;
  location?: Location;
}
export interface TerminalCreated extends Terminal {
  apiKey: string;
}

export interface Authorization {
  id: string;
  userId: string;
  locationId: string;
  startDate: string;
  endDate: string;
  startTime: string;
  endTime: string;
  maxUses: number | null;
  usedCount: number;
  remainingUses: number | null;
  status: AuthStatus;
  createdById?: string;
  createdAt?: string;
  canceledAt?: string | null;
  canceledById?: string | null;
  location?: Location;
  user?: { id: string; name: string };
}

export interface AccessLog {
  id: string;
  userId: string | null;
  terminalId: string;
  method: Method;
  result: AccessResult;
  reason: string | null;
  nfcUid: string | null;
  createdAt: string;
  user?: { id: string; name: string } | null;
  terminal?: { id: string; name: string };
}

// Painel (US-15, US-16). Os endpoints /dashboard/* ainda não existem no backend: por ora só o modo demonstração os simula.
export interface DashboardSummary {
  date: string;
  granted: number;
  denied: number;
  /** fração de 0 a 1 */
  denialRate: number;
  byMethod: Record<Method, number>;
  authorizations: { active: number; expiringSoon: number; canceled: number };
  topDenialReasons: { reason: string; count: number }[];
}
export interface HourBucket {
  hour: number;
  granted: number;
  denied: number;
}
/** Resposta de GET /terminals/{id}/status. `lock` ainda não existe no backend. */
export interface TerminalStatus {
  id: string;
  online: boolean;
  presenceActive: boolean;
  lastPresenceAt: string | null;
  lastSeenAt: string | null;
  lock?: "LOCKED" | "UNLOCKED";
}
