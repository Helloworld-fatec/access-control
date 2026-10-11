// backend/src/models/access-log.model.ts
import type { AccessMethod, AccessResult, DenyReason } from "../types/index";

export interface AccessLogRow {
  id: string;
  userId: string | null;
  terminalId: string;
  authorizationId: string | null;
  method: string;
  result: string;
  reason: string | null;
  nfcUid: string | null;
  confidence: number | null;
  distanceMeters: number | null;
  commandAcked: boolean | null;
  createdAt: Date;
}

export interface AccessLogResponse {
  id: string;
  userId: string | null;
  terminalId: string;
  authorizationId: string | null;
  method: AccessMethod;
  result: AccessResult;
  reason: DenyReason | null;
  nfcUid: string | null;
  confidence: number | null;
  distanceMeters: number | null;
  commandAcked: boolean | null;
  createdAt: Date;
  user?: { id: string; name: string } | null;
  terminal?: { id: string; name: string };
}

export function toAccessLogResponse(
  l: AccessLogRow & {
    user?: { id: string; name: string } | null;
    terminal?: { id: string; name: string };
  },
): AccessLogResponse {
  return {
    id: l.id,
    userId: l.userId,
    terminalId: l.terminalId,
    authorizationId: l.authorizationId,
    method: l.method as AccessMethod,
    result: l.result as AccessResult,
    reason: l.reason as DenyReason | null,
    nfcUid: l.nfcUid,
    confidence: l.confidence,
    distanceMeters: l.distanceMeters,
    commandAcked: l.commandAcked,
    createdAt: l.createdAt,
    ...(l.user !== undefined ? { user: l.user } : {}),
    ...(l.terminal ? { terminal: l.terminal } : {}),
  };
}
