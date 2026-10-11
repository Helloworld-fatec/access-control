// backend/src/models/dtos/location.dto.ts
import { z } from "zod";
import { paginationSchema } from "./common.dto";

const optionalText = z
  .string()
  .trim()
  .max(120)
  .transform((v) => (v === "" ? undefined : v))
  .optional();

export const createLocationSchema = z.object({
  building: z.string().trim().min(1, "Informe o edifício").max(120),
  entrance: optionalText, // portaria
  door: optionalText,
  turnstile: optionalText, // catraca
  description: z.string().trim().max(500).optional(),
});

export const updateLocationSchema = createLocationSchema
  .partial()
  .refine((v) => Object.keys(v).length > 0, "Envie ao menos um campo");

export const listLocationsQuerySchema = paginationSchema.extend({
  search: z.string().trim().min(1).optional(),
});

export type CreateLocationDto = z.infer<typeof createLocationSchema>;
export type UpdateLocationDto = z.infer<typeof updateLocationSchema>;
export type ListLocationsQuery = z.infer<typeof listLocationsQuerySchema>;
