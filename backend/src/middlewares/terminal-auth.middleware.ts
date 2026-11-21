import type { NextFunction, Request, Response } from "express";
import { prisma } from "../config/prisma.js";
import { hashTerminalKey, terminalKeyPattern } from "../config/terminal-key.js";
import { rateLimit } from "./rate-limit.middleware.js";

declare global {
  namespace Express {
    interface Request {
      terminal?: { id: string; locationId: string };
    }
  }
}

export const limitTerminalAuth = rateLimit({
  windowMs: 60_000,
  max: 30,
  key: (req) => req.ip ?? req.socket.remoteAddress ?? "unknown",
  countStatus: 401,
});

export async function authenticateTerminal(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  const bearer = req.get("authorization")?.match(/^Bearer\s+(\S+)$/i)?.[1];
  const apiKey = req.get("x-terminal-key") ?? req.get("x-api-key") ?? bearer;
  if (!apiKey || !terminalKeyPattern.test(apiKey)) {
    res.status(401).json({
      error: { code: "TERMINAL_UNAUTHORIZED", message: "Credencial do terminal obrigatória" },
    });
    return;
  }

  try {
    const terminal = await prisma.terminal.findUnique({
      where: { apiKeyHash: hashTerminalKey(apiKey) },
      select: { id: true, locationId: true },
    });

    if (!terminal) {
      res.status(401).json({
        error: { code: "TERMINAL_UNAUTHORIZED", message: "Credencial do terminal inválida" },
      });
      return;
    }

    if (req.params.id && req.params.id !== terminal.id) {
      res.status(403).json({
        error: { code: "TERMINAL_FORBIDDEN", message: "Credencial não pertence a este terminal" },
      });
      return;
    }

    req.terminal = { id: terminal.id, locationId: terminal.locationId };
    await prisma.terminal.update({
      where: { id: terminal.id },
      data: { lastSeenAt: new Date() },
      select: { id: true },
    });
    next();
  } catch (error) {
    next(error);
  }
}
