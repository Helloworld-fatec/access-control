import { createHash, randomBytes } from "node:crypto";
import type { Request, Response } from "express";
import { prisma } from "../config/prisma.js";
import { AppError } from "../middlewares/error.middleware.js";
import { consumeQrSchema } from "../models/dtos/qr-access.dto.js";
import { ACCESS_METHODS, ACCESS_RESULTS, DENY_REASONS } from "../types/index.js";
import { requestDoorUnlock } from "../services/door-unlock.service.js";

const QR_TTL_SECONDS = 300;
const hashToken = (token: string) => createHash("sha256").update(token).digest("hex");
const dateOnly = (date: Date) => date.toISOString().slice(0, 10);

function saoPauloNow(now: Date) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Sao_Paulo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(now);
  const value = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((part) => part.type === type)?.value ?? "";
  const today = `${value("year")}-${value("month")}-${value("day")}`;
  const time = new Intl.DateTimeFormat("en-GB", {
    timeZone: "America/Sao_Paulo",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).format(now);
  return { today, time };
}

// POST /terminals/me/qr — autenticado pela API key do próprio terminal.
export async function issueQr(req: Request, res: Response) {
  if (!req.terminal) throw new AppError(401, "Terminal não autenticado", "TERMINAL_UNAUTHORIZED");

  const token = randomBytes(32).toString("base64url");
  const expiresAt = new Date(Date.now() + QR_TTL_SECONDS * 1000);

  await prisma.qrnonce.create({
    data: {
      nonce: hashToken(token),
      terminalId: req.terminal.id,
      expiresAt,
    },
  });

  res.json({
    payload: { v: 1, token },
    expiresAt: expiresAt.toISOString(),
    refreshAfterSeconds: Math.floor(QR_TTL_SECONDS * 2 / 3),
  });
}

// POST /access/qr/consume — autenticado pelo JWT do app-user.
export async function consumeQr(req: Request, res: Response) {
  if (!req.auth) throw new AppError(401, "Usuário não autenticado", "UNAUTHORIZED");
  const userId = req.auth.userId;
  const { token } = consumeQrSchema.parse(req.body);
  const tokenHash = hashToken(token);
  const now = new Date();
  const { today, time } = saoPauloNow(now);
  const todayDate = new Date(`${today}T00:00:00.000Z`);

  const outcome = await prisma.$transaction(async (tx) => {
    const qr = await tx.qrnonce.findUnique({
      where: { nonce: tokenHash },
      include: { terminal: { select: { id: true, locationId: true } } },
    });
    if (!qr) return { kind: "UNKNOWN" as const };

    // Claim atômico: apenas uma requisição pode consumir este QR.
    const claim = await tx.qrnonce.updateMany({
      where: { nonce: tokenHash, consumedAt: null },
      data: { consumedAt: now },
    });

    let reason: string | null = null;
    let authorizationId: string | null = null;
    let logUserId: string | null = userId;

    if (claim.count === 0) {
      reason = DENY_REASONS.REPLAYED_CREDENTIAL;
    } else if (qr.expiresAt <= now) {
      reason = DENY_REASONS.EXPIRED_CREDENTIAL;
    }

    const user = await tx.user.findUnique({
      where: { id: userId },
      select: { id: true, active: true },
    });
    if (!user) logUserId = null;

    if (!reason && (!user || !user.active)) {
      reason = DENY_REASONS.USER_INACTIVE;
    }

    let grantedAuthorizationId: string | null = null;
    if (!reason && user) {
      const authorizations = await tx.authorization.findMany({
        where: { userId: user.id, locationId: qr.terminal.locationId },
        orderBy: { createdAt: "desc" },
      });

      if (authorizations.length === 0) {
        reason = DENY_REASONS.NO_AUTHORIZATION;
      } else {
        const active = authorizations.filter((authorization) => authorization.status === "ACTIVE");
        if (active.length === 0) {
          reason = DENY_REASONS.AUTHORIZATION_CANCELED;
          authorizationId = authorizations[0]?.id ?? null;
        } else {
          const inPeriod = active.filter(
            (authorization) =>
              dateOnly(authorization.startDate) <= today && dateOnly(authorization.endDate) >= today,
          );
          if (inPeriod.length === 0) {
            reason = DENY_REASONS.OUTSIDE_PERIOD;
            authorizationId = active[0]?.id ?? null;
          } else {
            const inSchedule = inPeriod.filter(
              (authorization) => authorization.startTime <= time && time <= authorization.endTime,
            );
            if (inSchedule.length === 0) {
              reason = DENY_REASONS.OUTSIDE_SCHEDULE;
              authorizationId = inPeriod[0]?.id ?? null;
            } else {
              let exhaustedAuthorizationId: string | null = null;
              for (const authorization of inSchedule) {
                authorizationId = authorization.id;
                if (
                  authorization.maxUses !== null &&
                  authorization.usedCount >= authorization.maxUses
                ) {
                  exhaustedAuthorizationId = authorization.id;
                  continue;
                }

                const updated = await tx.authorization.updateMany({
                  where: {
                    id: authorization.id,
                    status: "ACTIVE",
                    usedCount: authorization.usedCount,
                    maxUses: authorization.maxUses,
                    startDate: { lte: todayDate },
                    endDate: { gte: todayDate },
                  },
                  data: { usedCount: { increment: 1 } },
                });
                if (updated.count === 1) {
                  grantedAuthorizationId = authorization.id;
                  reason = null;
                  break;
                }
                exhaustedAuthorizationId = authorization.id;
              }

              if (!grantedAuthorizationId) {
                reason = DENY_REASONS.USES_EXHAUSTED;
                authorizationId = exhaustedAuthorizationId ?? inSchedule[0]?.id ?? null;
              }
            }
          }
        }
      }
    }

    const granted = grantedAuthorizationId !== null && reason === null;
    const accessLog = await tx.accesslog.create({
      data: {
        userId: logUserId,
        terminalId: qr.terminalId,
        authorizationId: granted ? grantedAuthorizationId : authorizationId,
        method: ACCESS_METHODS.QR,
        result: granted ? ACCESS_RESULTS.GRANTED : ACCESS_RESULTS.DENIED,
        reason: granted ? null : reason ?? DENY_REASONS.NO_AUTHORIZATION,
      },
    });

    return {
      kind: granted ? ("GRANTED" as const) : ("DENIED" as const),
      accessLogId: accessLog.id,
      terminalId: qr.terminalId,
      userId: logUserId,
      authorizationId: grantedAuthorizationId,
      reason: granted ? null : reason ?? DENY_REASONS.NO_AUTHORIZATION,
    };
  });

  if (outcome.kind === "UNKNOWN") {
    throw new AppError(401, "QR inválido ou desconhecido", "INVALID_CREDENTIAL");
  }

  if (outcome.kind === "DENIED") {
    res.status(403).json({
      result: ACCESS_RESULTS.DENIED,
      reason: outcome.reason,
      accessLogId: outcome.accessLogId,
    });
    return;
  }

  await requestDoorUnlock({
    terminalId: outcome.terminalId,
    userId: outcome.userId ?? req.auth.userId,
    accessLogId: outcome.accessLogId,
    method: ACCESS_METHODS.QR,
  });

  res.json({
    result: ACCESS_RESULTS.GRANTED,
    accessLogId: outcome.accessLogId,
    terminalId: outcome.terminalId,
    authorizationId: outcome.authorizationId,
  });
}
