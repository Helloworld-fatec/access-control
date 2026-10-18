// backend/src/controllers/terminals.controller.ts
import { createHash, randomBytes } from "node:crypto";
import type { Request, Response } from "express";
import type { Prisma } from "../generated/prisma/client.js";
import { prisma } from "../config/prisma.js";
import { AppError } from "../middlewares/error.middleware.js";
import {
  createTerminalSchema,
  idParamSchema,
  listTerminalsQuerySchema,
  updateTerminalSchema,
} from "../models/dtos/index.js";
import { paginate, toTerminalResponse, type TerminalCreatedResponse } from "../models/index.js";

const notFound = () => new AppError(404, "Terminal não encontrado", "TERMINAL_NOT_FOUND");
const locationNotFound = () =>
  new AppError(404, "Local não encontrado", "LOCATION_NOT_FOUND");

/**
 * A apiKey é aleatória e longa (192 bits), então SHA-256 basta para guardá-la
 * (bcrypt seria lento demais a cada requisição do terminal).
 */
export const hashApiKey = (apiKey: string) =>
  createHash("sha256").update(apiKey).digest("hex");

// GET /terminals
export async function listTerminals(req: Request, res: Response) {
  const q = listTerminalsQuerySchema.parse(req.query);
  const where: Prisma.terminalWhereInput = q.locationId ? { locationId: q.locationId } : {};

  const [rows, total] = await prisma.$transaction([
    prisma.terminal.findMany({
      where,
      include: { location: true },
      orderBy: { name: "asc" },
      skip: (q.page - 1) * q.pageSize,
      take: q.pageSize,
    }),
    prisma.terminal.count({ where }),
  ]);

  res.json(paginate(rows.map(toTerminalResponse), total, q.page, q.pageSize));
}

// GET /terminals/:id
export async function getTerminal(req: Request, res: Response) {
  const { id } = idParamSchema.parse(req.params);

  const terminal = await prisma.terminal.findUnique({
    where: { id },
    include: { location: true },
  });
  if (!terminal) throw notFound();

  res.json(toTerminalResponse(terminal));
}

// POST /terminals
export async function createTerminal(req: Request, res: Response) {
  const dto = createTerminalSchema.parse(req.body);

  const location = await prisma.location.findUnique({
    where: { id: dto.locationId },
    select: { id: true },
  });
  if (!location) throw locationNotFound();

  const apiKey = randomBytes(24).toString("hex");
  const terminal = await prisma.terminal.create({
    data: {
      ...dto,
      qrSecret: randomBytes(32).toString("hex"),
      apiKeyHash: hashApiKey(apiKey),
    },
    include: { location: true },
  });

  // A apiKey em texto puro só é devolvida agora; depois não há como recuperá-la.
  const body: TerminalCreatedResponse = { ...toTerminalResponse(terminal), apiKey };
  res.status(201).json(body);
}

// PUT /terminals/:id
export async function updateTerminal(req: Request, res: Response) {
  const { id } = idParamSchema.parse(req.params);
  const dto = updateTerminalSchema.parse(req.body);

  if (dto.locationId) {
    const location = await prisma.location.findUnique({
      where: { id: dto.locationId },
      select: { id: true },
    });
    if (!location) throw locationNotFound();
  }

  const terminal = await prisma.terminal.update({
    where: { id },
    data: dto,
    include: { location: true },
  });

  res.json(toTerminalResponse(terminal));
}

// DELETE /terminals/:id
export async function deleteTerminal(req: Request, res: Response) {
  const { id } = idParamSchema.parse(req.params);

  const logs = await prisma.accesslog.count({ where: { terminalId: id } });
  if (logs > 0) {
    throw new AppError(
      409,
      "Terminal possui histórico de acessos e não pode ser removido",
      "TERMINAL_IN_USE",
    );
  }

  await prisma.terminal.delete({ where: { id } });

  res.status(204).send();
}
