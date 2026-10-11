// backend/src/controllers/access-logs.controller.ts
import type { Request, Response } from "express";
import type { Prisma } from "../generated/prisma/client.js";
import { prisma } from "../config/prisma.js";
import { listAccessLogsQuerySchema } from "../models/dtos/index.js";
import { paginate, toAccessLogResponse } from "../models/index.js";

// Brasil não tem horário de verão desde 2019: o offset de São Paulo é fixo (-03:00).
const startOfDay = (d: string) => new Date(`${d}T00:00:00.000-03:00`);
const endOfDay = (d: string) => new Date(`${d}T23:59:59.999-03:00`);

// GET /access-logs  (somente leitura: quem grava é o módulo de acesso, futuramente)
export async function listAccessLogs(req: Request, res: Response) {
  const q = listAccessLogsQuerySchema.parse(req.query);

  const where: Prisma.AccessLogWhereInput = {
    ...(q.userId ? { userId: q.userId } : {}),
    ...(q.terminalId ? { terminalId: q.terminalId } : {}),
    ...(q.method ? { method: q.method } : {}),
    ...(q.result ? { result: q.result } : {}),
    ...(q.from || q.to
      ? {
          createdAt: {
            ...(q.from ? { gte: startOfDay(q.from) } : {}),
            ...(q.to ? { lte: endOfDay(q.to) } : {}),
          },
        }
      : {}),
  };

  const [rows, total] = await prisma.$transaction([
    prisma.accessLog.findMany({
      where,
      include: {
        user: { select: { id: true, name: true } },
        terminal: { select: { id: true, name: true } },
      },
      orderBy: { createdAt: "desc" },
      skip: (q.page - 1) * q.pageSize,
      take: q.pageSize,
    }),
    prisma.accessLog.count({ where }),
  ]);

  res.json(paginate(rows.map(toAccessLogResponse), total, q.page, q.pageSize));
}
