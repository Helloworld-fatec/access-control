import type { Request, Response } from "express";
import { z } from "zod";
import { prisma } from "../config/prisma.js";
import { dateOnlySchema } from "../models/dtos/common.dto.js";
import { todayInSaoPaulo } from "../models/index.js";
import { ACCESS_METHODS, ACCESS_RESULTS, AUTHORIZATION_STATUSES, type AccessMethod } from "../types/index.js";

const dashboardDate = dateOnlySchema.refine((date) => !date.startsWith("0000-"), "Data inválida");
const dashboardQuery = z.object({ date: dashboardDate.optional() });
const timeZone = "America/Sao_Paulo";

interface AccessGroup {
  hour: number;
  method: string;
  result: string;
  reason: string | null;
  count: bigint;
}

function dateFrom(req: Request) {
  return dashboardQuery.parse(req.query).date ?? todayInSaoPaulo();
}

function accessGroups(date: string) {
  // O Prisma grava createdAt em UTC, em uma coluna timestamp sem fuso.
  return prisma.$queryRaw<AccessGroup[]>`
    SELECT EXTRACT(HOUR FROM ("createdAt" AT TIME ZONE 'UTC') AT TIME ZONE ${timeZone})::int AS hour,
           method, result, reason, COUNT(*) AS count
    FROM "access_logs"
    WHERE "createdAt" >= ((${date}::date::timestamp AT TIME ZONE ${timeZone}) AT TIME ZONE 'UTC')
      AND "createdAt" < (((${date}::date + 1)::timestamp AT TIME ZONE ${timeZone}) AT TIME ZONE 'UTC')
    GROUP BY 1, 2, 3, 4
  `;
}

export async function summary(req: Request, res: Response) {
  const date = dateFrom(req);
  const today = new Date(`${todayInSaoPaulo()}T00:00:00Z`);
  const inSevenDays = new Date(today);
  inSevenDays.setUTCDate(inSevenDays.getUTCDate() + 7);

  const [groups, active, expiringSoon, canceled] = await prisma.$transaction([
    accessGroups(date),
    prisma.authorization.count({
      where: { status: AUTHORIZATION_STATUSES.ACTIVE, endDate: { gte: today } },
    }),
    prisma.authorization.count({
      where: { status: AUTHORIZATION_STATUSES.ACTIVE, endDate: { gte: today, lte: inSevenDays } },
    }),
    prisma.authorization.count({ where: { status: AUTHORIZATION_STATUSES.CANCELED } }),
  ]);

  const byMethod: Record<AccessMethod, number> = { QR: 0, NFC: 0, FACE: 0 };
  const methods = new Set<string>(Object.values(ACCESS_METHODS));
  const reasons = new Map<string, number>();
  let granted = 0;
  let denied = 0;
  for (const { method, result, reason, count } of groups) {
    const total = Number(count);
    if (result === ACCESS_RESULTS.GRANTED) granted += total;
    else if (result === ACCESS_RESULTS.DENIED) {
      denied += total;
      if (reason) reasons.set(reason, (reasons.get(reason) ?? 0) + total);
    } else continue;
    if (methods.has(method)) byMethod[method as AccessMethod] += total;
  }
  const topDenialReasons = [...reasons]
    .sort(([a, countA], [b, countB]) => countB - countA || a.localeCompare(b))
    .slice(0, 5)
    .map(([reason, count]) => ({ reason, count }));

  res.json({
    date, granted, denied,
    denialRate: granted + denied ? denied / (granted + denied) : 0,
    byMethod,
    authorizations: { active, expiringSoon, canceled },
    topDenialReasons,
  });
}

export async function accessesByHour(req: Request, res: Response) {
  const groups = await accessGroups(dateFrom(req));
  const hours = Array.from({ length: 24 }, (_, hour) => ({ hour, granted: 0, denied: 0 }));
  for (const { hour, result, count } of groups) {
    if (result === ACCESS_RESULTS.GRANTED) hours[hour].granted += Number(count);
    if (result === ACCESS_RESULTS.DENIED) hours[hour].denied += Number(count);
  }
  res.json(hours);
}
