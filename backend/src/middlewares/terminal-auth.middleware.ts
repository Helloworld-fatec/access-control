import type { NextFunction, Request, Response } from "express";
import { prisma } from '../config/prisma.js';
import { hashApiKey } from "../controllers/terminals.controller.js";
import { AppError, asyncHandler } from "./error.middleware.js";

export const requireTerminalAuth = asyncHandler(
    async (req: Request, res: Response, next: NextFunction) => {
        const bearer = req.header("authorization")?.replace(/^Bearer\s+/i, "").trim();
        const apiKey = (req.header("x-api-key")?.trim() || bearer || "");

        if (!apiKey) {
            throw new AppError(401, "Chave do terminal obrigatória", "TERMINAL_UNAUTHORIZED");
        }

        const terminalId = req.params.id ?? req.body?.terminalId;
        if (!terminalId || typeof terminalId !== "string") {
            throw new AppError(400, "Identificador do terminal ausente", "TERMINAL_ID_REQUIRED");
        }

        const terminal = await prisma.terminal.findUnique({ where: { id: terminalId } });
        if (!terminal || terminal.apiKeyHash !== hashApiKey(apiKey)) {
            throw new AppError(401, "Credencial de terminal inválida", "TERMINAL_UNAUTHORIZED");
        }

        await prisma.terminal.update({
            where: { id: terminal.id },
            data: { lastSeenAt: new Date(), online: true },
        });

        res.locals.terminal = terminal;
        next();
    },
);