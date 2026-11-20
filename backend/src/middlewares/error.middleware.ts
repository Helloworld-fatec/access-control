// backend/src/middlewares/error.middleware.ts
import type { NextFunction, Request, RequestHandler, Response } from "express";
import { ZodError } from "zod";

/** Erro esperado, com status HTTP e mensagem seguras para o cliente. */
export class AppError extends Error {
  readonly status: number;
  readonly code: string;
  readonly details?: unknown;

  constructor(status: number, message: string, code = "ERROR", details?: unknown) {
    super(message);
    this.name = "AppError";
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

/** Repassa erros de handlers async para o errorHandler (vale no Express 4 e 5). */
export function asyncHandler(
  fn: (req: Request, res: Response, next: NextFunction) => Promise<unknown> | unknown,
): RequestHandler {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

export function notFoundHandler(req: Request, res: Response): void {
  res.status(404).json({
    error: { code: "NOT_FOUND", message: `Rota não encontrada: ${req.method} ${req.path}` },
  });
}

interface ErrorLike {
  code?: unknown;
  name?: unknown;
  type?: unknown;
}

// Formato único de erro: { error: { code, message, details? } }
export function errorHandler(
  err: unknown,
  _req: Request,
  res: Response,
  _next: NextFunction,
): void {
  if (err instanceof AppError) {
    res.status(err.status).json({
      error: { code: err.code, message: err.message, details: err.details },
    });
    return;
  }

  if (err instanceof ZodError) {
    res.status(400).json({
      error: {
        code: "VALIDATION_ERROR",
        message: "Dados inválidos",
        details: err.issues.map((i) => ({ path: i.path.join("."), message: i.message })),
      },
    });
    return;
  }

  const e = (err ?? {}) as ErrorLike;

  // JSON malformado (express.json)
  if (e.type === "entity.parse.failed") {
    res.status(400).json({ error: { code: "INVALID_JSON", message: "JSON inválido" } });
    return;
  }

  // Erros do multer (upload)
  if (e.name === "MulterError") {
    const tooBig = e.code === "LIMIT_FILE_SIZE";
    res.status(tooBig ? 413 : 400).json({
      error: {
        code: tooBig ? "FILE_TOO_LARGE" : "UPLOAD_ERROR",
        message: tooBig ? "Arquivo maior que o limite permitido" : "Falha no upload do arquivo",
      },
    });
    return;
  }

  // Erros conhecidos do Prisma (P2002 etc.), sem importar o runtime do Prisma aqui
  if (typeof e.code === "string" && /^P\d{4}$/.test(e.code)) {
    if (e.code === "P2002") {
      res.status(409).json({
        error: { code: "CONFLICT", message: "Já existe um registro com esses dados" },
      });
      return;
    }
    if (e.code === "P2025") {
      res.status(404).json({
        error: { code: "NOT_FOUND", message: "Registro não encontrado" },
      });
      return;
    }
    if (e.code === "P2003") {
      res.status(409).json({
        error: {
          code: "RELATION_ERROR",
          message: "Operação inválida: registro relacionado inexistente ou em uso",
        },
      });
      return;
    }
  }

  console.error(err);
  res.status(500).json({ error: { code: "INTERNAL_ERROR", message: "Erro interno do servidor" } });
}
