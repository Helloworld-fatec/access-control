// backend/src/models/dtos/terminal.dto.ts
import { z } from "zod";
import { paginationSchema } from "./common.dto.js";

const latitude = z.number().min(-90).max(90);
const longitude = z.number().min(-180).max(180);

/**
 * qrSecret e apiKey NÃO vêm do cliente: o backend gera ambos.
 * A apiKey em texto puro é devolvida uma única vez, na criação.
 */
export const createTerminalSchema = z.object({
  name: z.string().trim().min(1, "Informe o nome").max(120),
  locationId: z.string().uuid("locationId inválido"),
  latitude,
  longitude,
});

export const updateTerminalSchema = z
  .object({
    name: z.string().trim().min(1).max(120),
    locationId: z.string().uuid(),
    latitude,
    longitude,
  })
  .partial()
  .refine((v) => Object.keys(v).length > 0, "Envie ao menos um campo");

export const listTerminalsQuerySchema = paginationSchema.extend({
  locationId: z.string().uuid().optional(),
});

export type CreateTerminalDto = z.infer<typeof createTerminalSchema>;
export type UpdateTerminalDto = z.infer<typeof updateTerminalSchema>;
export type ListTerminalsQuery = z.infer<typeof listTerminalsQuerySchema>;
