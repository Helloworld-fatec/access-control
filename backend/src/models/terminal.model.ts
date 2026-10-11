// backend/src/models/terminal.model.ts
import { toLocationResponse, type LocationResponse, type LocationRow } from "./location.model";

export interface TerminalRow {
  id: string;
  name: string;
  locationId: string;
  latitude: number;
  longitude: number;
  qrSecret: string;
  apiKeyHash: string;
  online: boolean;
  lastPresenceAt: Date | null;
  lastSeenAt: Date | null;
  createdAt: Date;
}

/** Nunca expõe qrSecret nem apiKeyHash. */
export interface TerminalResponse {
  id: string;
  name: string;
  locationId: string;
  latitude: number;
  longitude: number;
  online: boolean;
  lastPresenceAt: Date | null;
  lastSeenAt: Date | null;
  createdAt: Date;
  location?: LocationResponse;
}

/** Resposta da criação: a apiKey em texto puro aparece só desta vez. */
export interface TerminalCreatedResponse extends TerminalResponse {
  apiKey: string;
}

export function toTerminalResponse(
  t: TerminalRow & { location?: LocationRow },
): TerminalResponse {
  return {
    id: t.id,
    name: t.name,
    locationId: t.locationId,
    latitude: t.latitude,
    longitude: t.longitude,
    online: t.online,
    lastPresenceAt: t.lastPresenceAt,
    lastSeenAt: t.lastSeenAt,
    createdAt: t.createdAt,
    ...(t.location ? { location: toLocationResponse(t.location) } : {}),
  };
}
