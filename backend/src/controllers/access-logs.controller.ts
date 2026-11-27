// backend/src/controllers/access-logs.controller.ts
import type { Request, Response } from "express";
import type { Prisma } from "../generated/prisma/client.js";
import { prisma } from "../config/prisma.js";
import { listAccessLogsQuerySchema, type ListAccessLogsQuery } from "../models/dtos/index.js";
import { paginate, toAccessLogResponse } from "../models/index.js";
import { CSV_BOM, csvLine, formatSaoPaulo } from "../utils/csv.js";
import { METHOD_LABEL, REASON_LABEL, RESULT_LABEL } from "../utils/labels.js";
import { AppError } from "../middlewares/error.middleware.js";

// Brasil não tem horário de verão desde 2019: o offset de São Paulo é fixo (-03:00).
const startOfDay = (d: string) => new Date(`${d}T00:00:00.000-03:00`);
const endOfDay = (d: string) => new Date(`${d}T23:59:59.999-03:00`);

// GET /access-logs  (somente leitura: quem grava é o módulo de acesso, futuramente)
export async function listAccessLogs(req: Request, res: Response) {
  const q = listAccessLogsQuerySchema.parse(req.query);

  const where: Prisma.accesslogWhereInput = {
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
}

export async function listAccessLogs(req: Request, res: Response) {
  const q = listAccessLogsQuerySchema.parse(req.query);
  const where = buildWhere(q);

  const [rows, total] = await prisma.$transaction([
    prisma.accesslog.findMany({
      where,
      include: {
        user: { select: { id: true, name: true } },
        terminal: { select: { id: true, name: true } },
      },
      orderBy: { createdAt: "desc" },
      skip: (q.page - 1) * q.pageSize,
      take: q.pageSize,
    }),
    prisma.accesslog.count({ where }),
  ]);

  res.json(paginate(rows.map(toAccessLogResponse), total, q.page, q.pageSize));
}

// Limite para não montar arquivos gigantes: acima disso o administrador deve refinar os filtros.
export const EXPORT_MAX_ROWS = 50_000;
const BATCH = 1000;

// GET /access-logs/export  (CSV com os mesmos filtros da listagem; só administrador)
export async function exportAccessLogs(req: Request, res: Response) {
  const q = listAccessLogsQuerySchema.parse(req.query);
  const where = buildWhere(q);

  const total = await prisma.accessLog.count({ where });
  if (total > EXPORT_MAX_ROWS) {
    throw new AppError(413, `Há ${total} registros; o limite é ${EXPORT_MAX_ROWS}. Reduza o período ou use mais filtros.`, "EXPORT_TOO_LARGE");
  }

  const stamp = new Date().toISOString().slice(0, 10);
  res.status(200);
  res.setHeader("Content-Type", "text/csv; charset=utf-8");
  res.setHeader("Content-Disposition", `attachment; filename="historico-acessos-${stamp}.csv"`);
  res.setHeader("Cache-Control", "no-store");
  res.write(CSV_BOM + csvLine(["Data e hora", "Pessoa", "Terminal", "Método", "Resultado", "Motivo"]));

  try {
    // Lê em lotes (cursor) e escreve aos poucos: a memória não cresce com o tamanho do histórico.
    let cursor: string | undefined;
    for (;;) {
      const rows = await prisma.accessLog.findMany({
        where,
        include: { user: { select: { name: true } }, terminal: { select: { name: true } } },
        orderBy: [{ createdAt: "desc" }, { id: "desc" }],
        take: BATCH,
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      });
      if (rows.length === 0) break;
      let chunk = "";
      for (const l of rows) {
        chunk += csvLine([
          formatSaoPaulo(l.createdAt),
          l.user?.name ?? (l.nfcUid ? "Tag desconhecida" : "Não identificada"),
          l.terminal?.name ?? "",
          METHOD_LABEL[l.method] ?? l.method,
          RESULT_LABEL[l.result] ?? l.result,
          l.reason ? (REASON_LABEL[l.reason] ?? l.reason) : "",
        ]);
      }
      res.write(chunk);
      if (rows.length < BATCH) break;
      cursor = rows[rows.length - 1].id;
    }
    res.end();
  } catch (err) {
    // Os cabeçalhos já foram enviados: não dá para responder JSON. Encerra a conexão para o
    // cliente perceber que o arquivo está incompleto.
    console.error("Falha na exportação do histórico", err);
    res.destroy(err as Error);
  }
}
