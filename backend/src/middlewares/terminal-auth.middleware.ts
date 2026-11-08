import { createHash, timingSafeEqual } from "node:crypto";
import type { NextFunction, Request, Response } from "express";
import { prisma } from "../config/prisma.js";

declare global {
  namespace Express {
    interface Request {
      terminal?: { id: string; locationId: string };
    }
  }
}

export async function authenticateTerminal(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  const apiKey = req.get("x-terminal-key");
  if (!apiKey || !/^[\x21-\x7E]{24,200}$/.test(apiKey)) {
    res.status(401).json({
      error: { code: "TERMINAL_UNAUTHORIZED", message: "Credencial do terminal obrigatória" },
    });
    return;
  }

  try {
    const apiKeyHash = createHash("sha256").update(apiKey).digest("hex");
    const terminal = await prisma.terminal.findFirst({
      where: { apiKeyHash },
      select: { id: true, locationId: true, apiKeyHash: true },
    });

    const suppliedHash = Buffer.from(apiKeyHash, "hex");
    const storedHash = terminal ? Buffer.from(terminal.apiKeyHash, "hex") : Buffer.alloc(32);
    if (!terminal || !timingSafeEqual(suppliedHash, storedHash)) {
      res.status(401).json({
        error: { code: "TERMINAL_UNAUTHORIZED", message: "Credencial do terminal inválida" },
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
