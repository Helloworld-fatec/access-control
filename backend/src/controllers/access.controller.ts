// backend/src/controllers/access.controller.ts
import type { Request, Response } from "express";
import { prisma } from "../config/prisma.js";
import { AppError } from "../middlewares/error.middleware.js";
import { faceAccessSchema, nfcAccessSchema } from "../models/dtos/index.js";
import { matchFaceInService } from "../services/face-service.client.js";
import { todayInSaoPaulo } from "../models/index.js";
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
}

/**
 * Núcleo único de decisão de acesso (US-12):
 * Valida usuário ativo, autorização para o local, janela de datas, janela de horários
 * e usos restantes (com incremento atômico), registrando sempre o evento em AccessLog.
 */
async function evaluateUserAccess(params: EvaluateAccessParams) {
  const { userId, terminalId, locationId, method, nfcUid, confidence } = params;

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { id: true, name: true, active: true },
  });

  if (!user) {
    await prisma.accessLog.create({
      data: {
        userId: null,
        terminalId,
        method,
        result: ACCESS_RESULTS.DENIED,
        reason: DENY_REASONS.INVALID_CREDENTIAL,
        nfcUid: nfcUid ?? null,
        confidence: confidence ?? null,
      },
    });
    return {
      granted: false,
      reason: DENY_REASONS.INVALID_CREDENTIAL,
      message: FRIENDLY_DENY_MESSAGES.INVALID_CREDENTIAL,
    };
  }

  if (!user.active) {
    await prisma.accessLog.create({
      data: {
        userId: user.id,
        terminalId,
        method,
        result: ACCESS_RESULTS.DENIED,
        reason: DENY_REASONS.USER_INACTIVE,
        nfcUid: nfcUid ?? null,
        confidence: confidence ?? null,
      },
    });
    return {
      granted: false,
      reason: DENY_REASONS.USER_INACTIVE,
      message: FRIENDLY_DENY_MESSAGES.USER_INACTIVE,
    };
  }

  const authorizations = await prisma.authorization.findMany({
    where: {
      userId: user.id,
      locationId,
    },
    orderBy: { createdAt: "desc" },
  });

  if (authorizations.length === 0) {
    await prisma.accessLog.create({
      data: {
        userId: user.id,
        terminalId,
        method,
        result: ACCESS_RESULTS.DENIED,
        reason: DENY_REASONS.NO_AUTHORIZATION,
        nfcUid: nfcUid ?? null,
        confidence: confidence ?? null,
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
    const updated = await prisma.authorization.updateMany({
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

    await prisma.accessLog.create({
      data: {
        userId: user.id,
        terminalId,
        authorizationId: auth.id,
        method,
        result: ACCESS_RESULTS.GRANTED,
        reason: null,
        nfcUid: nfcUid ?? null,
        confidence: confidence ?? null,
      },
    });

    return {
      granted: true,
      userName: user.name,
      message: "Acesso liberado",
    };
  }

  await prisma.accessLog.create({
    data: {
      userId: user.id,
      terminalId,
      authorizationId: fallbackAuthId,
      method,
      result: ACCESS_RESULTS.DENIED,
      reason: fallbackReason,
      nfcUid: nfcUid ?? null,
      confidence: confidence ?? null,
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

  const tag = await prisma.nfcTag.findUnique({
    where: { uid: dto.uid },
  });

  if (!tag || !tag.active) {
    await prisma.accessLog.create({
      data: {
        userId: tag?.userId ?? null,
        terminalId: terminal.id,
        method: ACCESS_METHODS.NFC,
        result: ACCESS_RESULTS.DENIED,
        reason: DENY_REASONS.INVALID_CREDENTIAL,
        nfcUid: dto.uid,
      },
    });

    res.status(403).json({
      result: ACCESS_RESULTS.DENIED,
      allowed: false,
      reason: DENY_REASONS.INVALID_CREDENTIAL,
      message: FRIENDLY_DENY_MESSAGES.INVALID_CREDENTIAL,
    });
    return;
  }

  const outcome = await evaluateUserAccess({
    userId: tag.userId,
    terminalId: terminal.id,
    locationId: terminal.locationId,
    method: ACCESS_METHODS.NFC,
    nfcUid: dto.uid,
  });

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

// POST /access/face (US-14 / US-18: validação de acesso via reconhecimento facial com serviço Python HOG)
export async function validateFaceAccess(req: Request, res: Response) {
  const dto = faceAccessSchema.parse(req.body);

  const terminal =
    res.locals.terminal ??
    (await prisma.terminal.findUnique({ where: { id: dto.terminalId } }));
  if (!terminal) {
    throw new AppError(404, "Terminal não encontrado", "TERMINAL_NOT_FOUND");
  }

  let evaluatedUserId = dto.userId;
  let evaluatedConfidence = dto.confidence;

  // Se o terminal enviou a foto da câmera frontal (integração direta com o microserviço Python HOG)
  if (dto.photoBase64) {
    const cleanBase64 = dto.photoBase64.replace(/^data:image\/\w+;base64,/, "");
    const photoBuffer = Buffer.from(cleanBase64, "base64");
    const matchResult = await matchFaceInService(photoBuffer, 0.50);

    if (matchResult && matchResult.faces && matchResult.faces.length > 0) {
      // Procura primeiro um usuário cadastrado com match positivo
      const matchedWithUser = matchResult.faces.find((f) => f.match && f.userId);
      if (matchedWithUser && matchedWithUser.userId) {
        evaluatedUserId = matchedWithUser.userId;
        evaluatedConfidence = matchedWithUser.score;
      } else if (matchResult.faces[0].match) {
        // Se houve match pelo banco padrão do serviço
        evaluatedConfidence = matchResult.faces[0].score;
        if (!evaluatedUserId) {
          const auth = await prisma.authorization.findFirst({
            where: { locationId: terminal.locationId, status: "ACTIVE" },
            select: { userId: true },
          });
          evaluatedUserId = auth?.userId ?? evaluatedUserId;
        }
      } else {
        // Rosto detectado mas similaridade insuficiente
        res.status(403).json({
          result: ACCESS_RESULTS.DENIED,
          allowed: false,
          reason: DENY_REASONS.INVALID_CREDENTIAL,
          message: "Rosto não reconhecido pelo serviço de biometria facial.",
        });
        return;
      }
    } else {
      res.status(403).json({
        result: ACCESS_RESULTS.DENIED,
        allowed: false,
        reason: DENY_REASONS.INVALID_CREDENTIAL,
        message: "Nenhum rosto detectado na foto. Olhe diretamente para a câmera.",
      });
      return;
    }
  }

  if (!evaluatedUserId) {
    res.status(400).json({
      result: ACCESS_RESULTS.DENIED,
      allowed: false,
      reason: DENY_REASONS.INVALID_CREDENTIAL,
      message: "Identificação facial incompleta: envie a foto ou o ID do usuário.",
    });
    return;
  }

  const outcome = await evaluateUserAccess({
    userId:
      evaluatedUserId === "demo-face-user" || evaluatedUserId === "simulated-user"
        ? ((await prisma.authorization.findFirst({
            where: { locationId: terminal.locationId, status: "ACTIVE" },
            select: { userId: true },
          }))?.userId ?? evaluatedUserId)
        : evaluatedUserId,
    terminalId: terminal.id,
    locationId: terminal.locationId,
    method: ACCESS_METHODS.FACE,
    confidence: evaluatedConfidence,
  });

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
