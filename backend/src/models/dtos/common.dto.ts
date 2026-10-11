// backend/src/models/dtos/common.dto.ts
import { z } from "zod";

export const idParamSchema = z.object({
  id: z.string().uuid("ID inválido"),
});

export const paginationSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(20),
});

/** Data no formato YYYY-MM-DD (e que realmente exista no calendário). */
export const dateOnlySchema = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, "Use o formato AAAA-MM-DD")
  .refine((v) => {
    const d = new Date(`${v}T00:00:00Z`);
    return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === v;
  }, "Data inválida");

/** Horário no formato HH:mm (24h). */
export const timeSchema = z
  .string()
  .regex(/^([01]\d|2[0-3]):[0-5]\d$/, "Use o formato HH:mm");

/** Booleano vindo de query string ("true" | "false"). */
export const booleanQuerySchema = z
  .enum(["true", "false"])
  .transform((v) => v === "true");

export type PaginationQuery = z.infer<typeof paginationSchema>;
