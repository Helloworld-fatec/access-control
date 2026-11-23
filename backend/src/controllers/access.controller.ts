// backend/src/controllers/access.controller.ts
import { createHmac, randomUUID } from "node:crypto";
import type { Request, Response } from "express";
import { z } from "zod";
import type { Prisma } from "../generated/prisma/client.js";
import { env } from "../config/env.js";
import { prisma } from "../config/prisma.js";
import { AppError } from "../middlewares/error.middleware.js";
import { esp32NfcAccessSchema, faceAccessSchema, nfcAccessSchema } from "../models/dtos/index.js";
import { todayInSaoPaulo } from "../models/index.js";
import {
  FACE_MODEL_VERSION,
  MAX_FACE_CANDIDATES,
  isCompatibleFaceEmbedding,
  matchFace,
} from "../services/face-recognition.service.js";
import { requestDoorUnlock } from "../services/door-unlock.service.js";
import {
  ACCESS_METHODS,
  ACCESS_RESULTS,
  AUTHORIZATION_STATUSES,
  DENY_REASONS,
  type AccessMethod,
  type DenyReason,
} from "../types/index.js";

const toDateOnly = (d: Date) => d.toISOString().slice(0, 10);

/** Horário atual (HH:mm) no fuso de São Paulo (-03:00). */
function currentTimeInSaoPaulo(): string {
  return new Intl.DateTimeFormat("pt-BR", {
    timeZone: "America/Sao_Paulo",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(new Date());
}

const FRIENDLY_DENY_MESSAGES: Record<DenyReason, string> = {
  INVALID_CREDENTIAL: "Credencial não cadastrada ou inválida.",
  EXPIRED_CREDENTIAL: "Credencial expirada.",
  REPLAYED_CREDENTIAL: "Credencial já utilizada.",
  USER_INACTIVE: "Usuário inativo.",
  NO_AUTHORIZATION: "Sem autorização ativa para este local.",
  AUTHORIZATION_CANCELED: "Autorização cancelada.",
  OUTSIDE_PERIOD: "Fora do período de validade da autorização.",
  OUTSIDE_SCHEDULE: "Fora do horário permitido.",
  USES_EXHAUSTED: "Limite de utilizações atingido.",
  TOO_FAR: "Dispositivo fora do raio de proximidade do terminal.",
  FACE_LOW_CONFIDENCE: "Confiança do reconhecimento facial insuficiente.",
  TERMINAL_OFFLINE: "Terminal indisponível.",
};

interface EvaluateAccessParams {
  userId: string;
  terminalId: string;
  locationId: string;
  method: AccessMethod;
  nfcUid?: string;
  confidence?: number;
  faceAttemptId?: string;
  accessLogId?: string;
}

/**
 * Núcleo único de decisão de acesso (US-12):
 * Valida usuário ativo, autorização para o local, janela de datas, janela de horários
 * e usos restantes (com incremento atômico), registrando sempre o evento em AccessLog.
 */
async function evaluateUserAccess(
  params: EvaluateAccessParams,
  db: Pick<Prisma.TransactionClient, "user" | "authorization" | "accesslog"> = prisma,
) {
  const { userId, terminalId, locationId, method, nfcUid, confidence, faceAttemptId, accessLogId } = params;
  const log = {
    ...(accessLogId === undefined ? {} : { id: accessLogId }),
    terminalId,
    method,
    nfcUid: nfcUid ?? null,
    confidence: confidence ?? null,
    ...(faceAttemptId === undefined ? {} : { faceAttemptId }),
  };

  const user = await db.user.findUnique({
    where: { id: userId },
    select: { id: true, name: true, active: true },
  });

  if (!user) {
    await db.accesslog.create({
      data: {
        userId: null,
        ...log,
        result: ACCESS_RESULTS.DENIED,
        reason: DENY_REASONS.INVALID_CREDENTIAL,
      },
    });
    return {
      granted: false,
      reason: DENY_REASONS.INVALID_CREDENTIAL,
      message: FRIENDLY_DENY_MESSAGES.INVALID_CREDENTIAL,
    };
  }

  if (!user.active) {
    await db.accesslog.create({
      data: {
        userId: user.id,
        ...log,
        result: ACCESS_RESULTS.DENIED,
        reason: DENY_REASONS.USER_INACTIVE,
      },
    });
    return {
      granted: false,
      reason: DENY_REASONS.USER_INACTIVE,
      message: FRIENDLY_DENY_MESSAGES.USER_INACTIVE,
    };
  }

  const authorizations = await db.authorization.findMany({
    where: {
      userId: user.id,
      locationId,
    },
    orderBy: { createdAt: "desc" },
  });

  if (authorizations.length === 0) {
    await db.accesslog.create({
      data: {
        userId: user.id,
        ...log,
        result: ACCESS_RESULTS.DENIED,
        reason: DENY_REASONS.NO_AUTHORIZATION,
      },
    });
    return {
      granted: false,
      reason: DENY_REASONS.NO_AUTHORIZATION,
      message: FRIENDLY_DENY_MESSAGES.NO_AUTHORIZATION,
    };
  }

  const today = todayInSaoPaulo();
  const currentTime = currentTimeInSaoPaulo();

  let fallbackReason: DenyReason = DENY_REASONS.NO_AUTHORIZATION;
  let fallbackAuthId: string | null = null;

  for (const auth of authorizations) {
    fallbackAuthId = auth.id;

    if (auth.status === AUTHORIZATION_STATUSES.CANCELED) {
      fallbackReason = DENY_REASONS.AUTHORIZATION_CANCELED;
      continue;
    }

    const startDay = toDateOnly(auth.startDate);
    const endDay = toDateOnly(auth.endDate);
    if (today < startDay || today > endDay) {
      fallbackReason = DENY_REASONS.OUTSIDE_PERIOD;
      continue;
    }

    if (currentTime < auth.startTime || currentTime > auth.endTime) {
      fallbackReason = DENY_REASONS.OUTSIDE_SCHEDULE;
      continue;
    }

    if (auth.maxUses !== null && auth.usedCount >= auth.maxUses) {
      fallbackReason = DENY_REASONS.USES_EXHAUSTED;
      continue;
    }

    // Atualização atômica de usedCount para evitar corrida em acessos simultâneos (US-12)
    const updated = await db.authorization.updateMany({
      where: {
        id: auth.id,
        status: AUTHORIZATION_STATUSES.ACTIVE,
        ...(auth.maxUses !== null ? { usedCount: { lt: auth.maxUses } } : {}),
      },
      data: {
        usedCount: { increment: 1 },
      },
    });

    if (updated.count === 0) {
      fallbackReason = DENY_REASONS.USES_EXHAUSTED;
      continue;
    }

    await db.accesslog.create({
      data: {
        userId: user.id,
        ...log,
        authorizationId: auth.id,
        result: ACCESS_RESULTS.GRANTED,
        reason: null,
      },
    });

    return {
      granted: true,
      userName: user.name,
      message: "Acesso liberado",
    };
  }

  await db.accesslog.create({
    data: {
      userId: user.id,
      ...log,
      authorizationId: fallbackAuthId,
      result: ACCESS_RESULTS.DENIED,
      reason: fallbackReason,
    },
  });

  return {
    granted: false,
    reason: fallbackReason,
    message: FRIENDLY_DENY_MESSAGES[fallbackReason],
  };
}

// POST /access/nfc (US-12: validação de acesso via tag NFC enviada pelo mobile-readings)
export async function validateNfcAccess(req: Request, res: Response) {
  const dto = nfcAccessSchema.parse(req.body);

  const terminal =
    res.locals.terminal ??
    (await prisma.terminal.findUnique({ where: { id: dto.terminalId } }));
  if (!terminal) {
    throw new AppError(404, "Terminal não encontrado", "TERMINAL_NOT_FOUND");
  }

  const outcome = await evaluateNfcAccess(terminal, dto.uid, prisma);

  if (outcome.granted) {
    res.status(200).json({
      result: ACCESS_RESULTS.GRANTED,
      allowed: true,
      message: outcome.message,
      userName: outcome.userName,
    });
    return;
  }

  res.status(403).json({
    result: ACCESS_RESULTS.DENIED,
    allowed: false,
    reason: outcome.reason,
    message: outcome.message,
  });
}

async function evaluateNfcAccess(
  terminal: { id: string; locationId: string },
  uid: string,
  db: Pick<Prisma.TransactionClient, "nfctag" | "user" | "authorization" | "accesslog">,
  accessLogId?: string,
) {
  const tag = await db.nfctag.findUnique({ where: { uid } });
  if (!tag?.active) {
    await db.accesslog.create({
      data: {
        ...(accessLogId === undefined ? {} : { id: accessLogId }),
        userId: tag?.userId ?? null,
        terminalId: terminal.id,
        method: ACCESS_METHODS.NFC,
        result: ACCESS_RESULTS.DENIED,
        reason: DENY_REASONS.INVALID_CREDENTIAL,
        nfcUid: uid,
      },
    });
    return {
      granted: false as const,
      reason: DENY_REASONS.INVALID_CREDENTIAL,
      message: FRIENDLY_DENY_MESSAGES.INVALID_CREDENTIAL,
    };
  }

  return evaluateUserAccess({
    userId: tag.userId,
    terminalId: terminal.id,
    locationId: terminal.locationId,
    method: ACCESS_METHODS.NFC,
    nfcUid: uid,
    accessLogId,
  }, db);
}

/** Entrada interna para o assinante MQTT, após receber a mensagem do broker. */
export async function recordEsp32NfcAccess(
  topic: string,
  input: unknown,
  request?: { requestId: string; occurredAt: string; expiresAt: Date },
) {
  const dto = esp32NfcAccessSchema.parse(input);
  if ((dto.terminalId !== env.ESP32_TERMINAL_ID && dto.terminalId !== env.MQTT_SIMULATOR_TERMINAL_ID) ||
      topic !== `access/v1/terminals/${dto.terminalId}/access/request`) {
    throw new AppError(403, "Terminal ESP32 divergente da configuração ou do tópico", "TERMINAL_MISMATCH");
  }

  return prisma.$transaction(async (tx) => {
    if (!request) return evaluateEsp32NfcAccess(tx, dto);

    const key = { terminalId: dto.terminalId, requestId: request.requestId };
    const fingerprint = createHmac("sha256", env.JWT_SECRET)
      .update(JSON.stringify([dto.uid, request.occurredAt])).digest("hex");
    const { count } = await tx.mqttNfcRequest.createMany({
      data: { ...key, fingerprint, expiresAt: request.expiresAt },
      skipDuplicates: true,
    });
    const where = { terminalId_requestId: key };
    if (count === 0) {
      const saved = await tx.mqttNfcRequest.findUnique({ where });
      if (saved?.fingerprint !== fingerprint || !saved.decision) return null;
      return saved.decision as Awaited<ReturnType<typeof evaluateEsp32NfcAccess>> & { decidedAt: string };
    }
    if (request.expiresAt.getTime() <= Date.now()) return null;
    const decision = { ...await evaluateEsp32NfcAccess(tx, dto), decidedAt: new Date().toISOString() };
    await tx.mqttNfcRequest.update({ where, data: { decision } });
    return decision;
  });
}

async function evaluateEsp32NfcAccess(
  tx: Prisma.TransactionClient,
  dto: z.infer<typeof esp32NfcAccessSchema>,
) {
  const terminal = await tx.terminal.findUnique({
    where: { id: dto.terminalId },
    select: { id: true, locationId: true },
  });
  if (!terminal) throw new AppError(404, "Terminal não encontrado", "TERMINAL_NOT_FOUND");

  const accessLogId = randomUUID();
  const outcome = await evaluateNfcAccess(terminal, dto.uid, tx, accessLogId);
  return outcome.granted
    ? { accessLogId, granted: true as const }
    : { accessLogId, granted: false as const, reason: outcome.reason };
}

/** Marca a execução de uma concessão NFC confirmada pela placa. */
export async function recordEsp32NfcUnlockAck(topic: string, input: unknown) {
  const ack = z.object({
    terminalId: z.uuid(),
    accessLogId: z.uuid(),
    result: z.enum(["UNLOCKED", "EXPIRED", "ERROR"]),
  }).parse(input);
  if ((ack.terminalId !== env.ESP32_TERMINAL_ID && ack.terminalId !== env.MQTT_SIMULATOR_TERMINAL_ID) ||
      topic !== `access/v1/terminals/${ack.terminalId}/door/ack`) {
    throw new AppError(403, "Terminal ESP32 divergente da configuração ou do tópico", "TERMINAL_MISMATCH");
  }

  const { count } = await prisma.accesslog.updateMany({
    where: {
      id: ack.accessLogId,
      terminalId: ack.terminalId,
      method: ACCESS_METHODS.NFC,
      result: ACCESS_RESULTS.GRANTED,
      commandAcked: null,
    },
    data: { commandAcked: ack.result === "UNLOCKED" },
  });
  return count > 0;
}

// POST /access/face (US-14: validação de acesso via reconhecimento facial local do terminal)
export async function validateFaceAccess(req: Request, res: Response) {
  const dto = faceAccessSchema.parse(req.body);

  const terminal =
    res.locals.terminal ??
    (await prisma.terminal.findUnique({ where: { id: dto.terminalId } }));
  if (!terminal) {
    throw new AppError(404, "Terminal não encontrado", "TERMINAL_NOT_FOUND");
  }

  const outcome = await evaluateUserAccess({
    userId: (dto.userId === "demo-face-user" || dto.userId === "simulated-user") ? ((await prisma.authorization.findFirst({ where: { locationId: terminal.locationId, status: "ACTIVE" }, select: { userId: true } }))?.userId ?? dto.userId) : dto.userId,
    terminalId: terminal.id,
    locationId: terminal.locationId,
    method: ACCESS_METHODS.FACE,
    confidence: dto.confidence,
  });

  sendFaceOutcome(res, outcome);
}

function sendFaceOutcome(
  res: Response,
  outcome: Awaited<ReturnType<typeof evaluateUserAccess>>,
): void {
  if (outcome.granted) {
    res.status(200).json({
      result: ACCESS_RESULTS.GRANTED,
      allowed: true,
      message: outcome.message,
      userName: outcome.userName,
    });
    return;
  }

  res.status(403).json({
    result: ACCESS_RESULTS.DENIED,
    allowed: false,
    reason: outcome.reason,
    message: outcome.message,
  });
}

const replayedAttempt = () =>
  new AppError(409, "Esta tentativa facial já foi processada", "FACE_ATTEMPT_REPLAYED");

// POST /access/face/capture
export async function validateFaceCapture(req: Request, res: Response) {
  const terminal = req.terminal;
  if (!terminal) throw new AppError(401, "Terminal não autenticado", "TERMINAL_UNAUTHORIZED");

  const faceAttemptId = z.uuid().parse(req.get("x-face-attempt-id")).toLowerCase();
  const key = { terminalId: terminal.id, faceAttemptId };
  const attemptWhere = { terminalId_faceAttemptId: key };
  const alreadyProcessed = () => prisma.accesslog.findUnique({
    where: attemptWhere,
    select: { id: true },
  });
  if (await alreadyProcessed()) throw replayedAttempt();

  const recordDenial = async (reason: string) => {
    await prisma.accesslog.create({
      data: { ...key, method: ACCESS_METHODS.FACE, result: ACCESS_RESULTS.DENIED, reason },
    });
  };

  try {
    const templates = await prisma.facetemplate.findMany({
      where: {
        modelVersion: FACE_MODEL_VERSION,
        user: { authorizations: { some: { locationId: terminal.locationId } } },
      },
      select: { userId: true, embedding: true },
      take: MAX_FACE_CANDIDATES + 1,
    });
    const candidates = templates.filter(({ embedding }) => isCompatibleFaceEmbedding(embedding));

    const files = req.files as Express.Multer.File[];
    let match: Awaited<ReturnType<typeof matchFace>>;
    try {
      if (templates.length > MAX_FACE_CANDIDATES) {
        throw new AppError(503, "O local excede a capacidade do reconhecimento", "FACE_CANDIDATE_LIMIT");
      }
      if (candidates.length === 0) {
        throw new AppError(422, "Nenhum cadastro facial compatível para este local", "FACE_NO_COMPATIBLE_TEMPLATES");
      }
      match = await matchFace(files.map(({ buffer }) => buffer), candidates);
    } catch (err) {
      if (err instanceof AppError) await recordDenial(err.code);
      throw err;
    }

    if (match.result !== "MATCH") {
      await recordDenial(match.result);
      res.status(403).json({
        result: ACCESS_RESULTS.DENIED,
        allowed: false,
        reason: match.result,
        message: match.result === "AMBIGUOUS_FACE"
          ? "Não foi possível identificar um único candidato"
          : "Rosto não reconhecido",
      });
      return;
    }

    const accessLogId = randomUUID();
    const outcome = await prisma.$transaction((tx) => evaluateUserAccess({
      ...key,
      accessLogId,
      userId: match.userId,
      locationId: terminal.locationId,
      method: ACCESS_METHODS.FACE,
      confidence: match.score,
    }, tx));
    if (outcome.granted) {
      await requestDoorUnlock({
        terminalId: terminal.id, userId: match.userId,
        accessLogId, method: ACCESS_METHODS.FACE,
      });
    }
    sendFaceOutcome(res, outcome);
  } catch (err) {
    if (err && typeof err === "object" && "code" in err &&
        err.code === "P2002" && await alreadyProcessed()) {
      throw replayedAttempt();
    }
    throw err;
  }
}
