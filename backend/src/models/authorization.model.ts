// backend/src/models/authorization.model.ts
import type { AuthorizationStatus } from "../types/index.js";
import { toLocationResponse, type LocationResponse, type LocationRow } from "./location.model.js";

export interface AuthorizationRow {
  id: string;
  userId: string;
  locationId: string;
  startDate: Date;
  endDate: Date;
  startTime: string;
  endTime: string;
  maxUses: number | null;
  usedCount: number;
  status: string;
  createdById: string;
  canceledAt: Date | null;
  canceledById: string | null;
  createdAt: Date;
  updatedAt: Date;
}

/** ACTIVE | CANCELED vêm do banco; EXPIRED é calculada pela data. */
export type AuthorizationDisplayStatus = AuthorizationStatus | "EXPIRED";

export interface AuthorizationResponse {
  id: string;
  userId: string;
  locationId: string;
  startDate: string; // AAAA-MM-DD
  endDate: string; // AAAA-MM-DD
  startTime: string; // HH:mm
  endTime: string; // HH:mm
  maxUses: number | null;
  usedCount: number;
  remainingUses: number | null; // null = ilimitado
  status: AuthorizationDisplayStatus;
  createdById: string;
  canceledAt: Date | null;
  canceledById: string | null;
  createdAt: Date;
  location?: LocationResponse;
  user?: { id: string; name: string };
}

const toDateOnly = (d: Date) => d.toISOString().slice(0, 10);

/** Data de hoje (AAAA-MM-DD) no fuso de São Paulo, não em UTC. */
export function todayInSaoPaulo(): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "America/Sao_Paulo" }).format(
    new Date(),
  );
}

export function computeStatus(
  a: Pick<AuthorizationRow, "status" | "endDate">,
  today: string = todayInSaoPaulo(),
): AuthorizationDisplayStatus {
  if (a.status === "CANCELED") return "CANCELED";
  return toDateOnly(a.endDate) < today ? "EXPIRED" : "ACTIVE";
}

export function toAuthorizationResponse(
  a: AuthorizationRow & { location?: LocationRow; user?: { id: string; name: string } },
): AuthorizationResponse {
  return {
    id: a.id,
    userId: a.userId,
    locationId: a.locationId,
    startDate: toDateOnly(a.startDate),
    endDate: toDateOnly(a.endDate),
    startTime: a.startTime,
    endTime: a.endTime,
    maxUses: a.maxUses,
    usedCount: a.usedCount,
    remainingUses: a.maxUses == null ? null : Math.max(a.maxUses - a.usedCount, 0),
    status: computeStatus(a),
    createdById: a.createdById,
    canceledAt: a.canceledAt,
    canceledById: a.canceledById,
    createdAt: a.createdAt,
    ...(a.location ? { location: toLocationResponse(a.location) } : {}),
    ...(a.user ? { user: { id: a.user.id, name: a.user.name } } : {}),
  };
}
