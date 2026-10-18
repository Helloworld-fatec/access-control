import type { NextFunction, Request, Response } from "express";

export function requireAdmin(req: Request, res: Response, next: NextFunction) {
  if (req.auth?.role !== "ADMIN") {
    res.status(req.auth ? 403 : 401).json({
      error: {
        code: req.auth ? "FORBIDDEN" : "UNAUTHORIZED",
        message: req.auth ? "Acesso restrito a administradores" : "Autenticação obrigatória",
      },
    });
    return;
  }
  next();
}
