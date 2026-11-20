import type { Request, Response, NextFunction } from "express";
import jwt from "jsonwebtoken";
import { env } from "../config/env.js";
import { prisma } from "../config/prisma.js";
import { AppError, asyncHandler } from "./error.middleware.js";

declare global {
  namespace Express {
    interface Request {
      auth?: { userId: string; role: string };
    }
  }
}

export function authenticate(req: Request, res: Response, next: NextFunction) {
  const [scheme, token, extra] = (req.get("authorization") ?? "").split(" ");
  if (scheme?.toLowerCase() !== "bearer" || !token || extra) {
    res.status(401).json({ error: { code: "UNAUTHORIZED", message: "Token de acesso obrigatório" } });
    return;
  }

  try {
    const payload = jwt.verify(token, env.JWT_SECRET);
    if (typeof payload === "string" || !payload.sub || typeof payload.role !== "string") {
      throw new Error("Invalid token payload");
    }
    req.auth = { userId: payload.sub, role: payload.role };
  } catch {
    res.status(401).json({ error: { code: "INVALID_TOKEN", message: "Token inválido ou expirado" } });
    return;
  }
  next();
}

export const requireAdmin = asyncHandler(async (req, _res, next) => {
  if (!req.auth) throw new AppError(401, "User not authenticated", "UNAUTHORIZED");
  const user = await prisma.user.findUnique({
    where: { id: req.auth.userId },
    select: { role: true, active: true },
  });
  if (!user || !user.active || user.role !== "ADMIN") {
    throw new AppError(403, "Administrator access required", "FORBIDDEN");
  }
  next();
});
