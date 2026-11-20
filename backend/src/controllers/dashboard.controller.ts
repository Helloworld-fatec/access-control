// backend/src/controllers/dashboard.controller.ts
import type { Request, Response } from "express";
import { Prisma } from "../generated/prisma/client.js";
import { prisma } from "../config/prisma.js";
import { dashboardQuerySchema } from "../models/dtos/index.js";
import { todayInSaoPaulo } from "../models/authorization.model.js";
import {
  ACCESS_METHODS,
  ACCESS_RESULTS,
  AUTHORIZATION_STATUSES,
} from "../types/index.js";

// Brasil não tem horário de verão desde 2019: o offset de São Paulo é fixo (-03:00).
const startOfDay = (d: string) => new Date(`${d}T00:00:00.000-03:00`);
const nextDay = (d: string) => new Date(startOfDay(d).getTime() + 24 * 60 * 60 * 1000);
const dateOnly = (d: Date) => d.toISOString().slice(0, 10);
const addDays = (d: string, n: number) =>
  dateOnly(new Date(new Date(`${d}T00:00:00Z`).getTime() + n * 24 * 60 * 60 * 1000));

/** Prazo (em dias) para uma autorização contar como "expirando em breve". */
const EXPIRING_DAYS = 7;
/** Um terminal que falou com a API nesse intervalo é considerado online. */
const ONLINE_WINDOW_MS = 2 * 60 * 1000;
const PRESENCE_WINDOW_MS = 5_000;

// GET /dashboard/summary?date=AAAA-MM-DD
export async function getSummary(req: Request, res: Response) {
  const { date = todayInSaoPaulo() } = dashboardQuerySchema.parse(req.query);
  const range = { gte: startOfDay(date), lt: nextDay(date) };
  const today = todayInSaoPaulo();
  const dayAsDate = (d: string) => new Date(`${d}T00:00:00.000Z`);

  const [byResult, byMethod, denials, active, expiring, canceled] = await Promise.all([
    prisma.accessLog.groupBy({ by: ["result"], where: { createdAt: range }, _count: { _all: true } }),
    prisma.accessLog.groupBy({ by: ["method"], where: { createdAt: range }, _count: { _all: true } }),
    prisma.accessLog.groupBy({
      by: ["reason"],
      where: { createdAt: range, result: ACCESS_RESULTS.DENIED, reason: { not: null } },
      _count: { _all: true },
      orderBy: { _count: { reason: "desc" } },
      take: 5,
    }),
    // EXPIRED não existe no banco: é ACTIVE com endDate no passado (ver authorizations.controller).
    prisma.authorization.count({
      where: { status: AUTHORIZATION_STATUSES.ACTIVE, endDate: { gte: dayAsDate(today) } },
    }),
    prisma.authorization.count({
      where: {
        status: AUTHORIZATION_STATUSES.ACTIVE,
        endDate: { gte: dayAsDate(today), lte: dayAsDate(addDays(today, EXPIRING_DAYS)) },
      },
    }),
    prisma.authorization.count({ where: { status: AUTHORIZATION_STATUSES.CANCELED } }),
  ]);

  const count = (rows: { result?: string; method?: string; _count: { _all: number } }[], key: "result" | "method", v: string) =>
    rows.find((r) => r[key] === v)?._count._all ?? 0;

  const granted = count(byResult, "result", ACCESS_RESULTS.GRANTED);
  const denied = count(byResult, "result", ACCESS_RESULTS.DENIED);
  const total = granted + denied;

  res.json({
    date,
    granted,
    denied,
    denialRate: total === 0 ? 0 : denied / total,
    byMethod: {
      [ACCESS_METHODS.QR]: count(byMethod, "method", ACCESS_METHODS.QR),
      [ACCESS_METHODS.NFC]: count(byMethod, "method", ACCESS_METHODS.NFC),
      [ACCESS_METHODS.FACE]: count(byMethod, "method", ACCESS_METHODS.FACE),
    },
    authorizations: { active, expiringSoon: expiring, canceled },
    topDenialReasons: denials.map((d) => ({ reason: d.reason as string, count: d._count._all })),
  });
}

// GET /dashboard/accesses-by-hour?date=AAAA-MM-DD
export async function getAccessesByHour(req: Request, res: Response) {
  const { date = todayInSaoPaulo() } = dashboardQuerySchema.parse(req.query);

  // "createdAt" é guardado em UTC (timestamp sem fuso): converte para São Paulo antes de agrupar por hora.
  const rows = await prisma.$queryRaw<{ hour: number; result: string; total: number }[]>(Prisma.sql`
    SELECT EXTRACT(HOUR FROM ("createdAt" AT TIME ZONE 'UTC' AT TIME ZONE 'America/Sao_Paulo'))::int AS hour,
           "result",
           COUNT(*)::int AS total
    FROM "access_logs"
    WHERE "createdAt" >= ${startOfDay(date)} AND "createdAt" < ${nextDay(date)}
    GROUP BY 1, 2
  `);

  const buckets = Array.from({ length: 24 }, (_, hour) => ({ hour, granted: 0, denied: 0 }));
  for (const r of rows) {
    if (r.result === ACCESS_RESULTS.GRANTED) buckets[r.hour].granted = r.total;
    else if (r.result === ACCESS_RESULTS.DENIED) buckets[r.hour].denied = r.total;
  }
  res.json(buckets);
}

// GET /terminals/status  (administrador): situação de todos os terminais de uma vez
export async function listTerminalStatuses(_req: Request, res: Response) {
  const terminals = await prisma.terminal.findMany({
    orderBy: { name: "asc" },
    select: { id: true, name: true, online: true, lastPresenceAt: true, lastSeenAt: true },
  });
  const now = Date.now();
  const within = (d: Date | null, ms: number) => d != null && now - d.getTime() <= ms;

  res.json({
    data: terminals.map((t) => {
      const presenceActive = within(t.lastPresenceAt, PRESENCE_WINDOW_MS);
      return {
        id: t.id,
        name: t.name,
        // O backend não marca `online` sozinho; "falou com a API há pouco" também conta.
        online: t.online || within(t.lastSeenAt, ONLINE_WINDOW_MS),
        presence: presenceActive,
        presenceActive,
        lastPresenceAt: t.lastPresenceAt,
        lastSeenAt: t.lastSeenAt,
      };
    }),
  });
}
