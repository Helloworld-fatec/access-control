// backend/src/models/dtos/authorization.dto.ts
import { z } from "zod";
import { dateOnlySchema, paginationSchema, timeSchema } from "./common.dto.js";

/** Situação exibida ao cliente. EXPIRED é calculada na consulta (endDate < hoje). */
export const AUTHORIZATION_QUERY_STATUS = ["ACTIVE", "CANCELED", "EXPIRED"] as const;

export const createAuthorizationSchema = z
  .object({
    userId: z.string().uuid("userId inválido"),
    locationId: z.string().uuid("locationId inválido"),
    startDate: dateOnlySchema,
    endDate: dateOnlySchema,
    startTime: timeSchema,
    endTime: timeSchema,
    maxUses: z.number().int().positive().nullable().optional(),
    // TODO: sai daqui quando existir login; passará a vir do token do admin.
    createdById: z.string().uuid("createdById inválido"),
  })
  .refine((v) => v.endDate >= v.startDate, {
    message: "A data de término deve ser igual ou posterior à de início",
    path: ["endDate"],
  })
  .refine((v) => v.endTime > v.startTime, {
    message: "O horário de término deve ser posterior ao de início",
    path: ["endTime"],
  });

export const cancelAuthorizationSchema = z.object({
  // TODO: sai daqui quando existir login.
  canceledById: z.string().uuid("canceledById inválido"),
});

export const listAuthorizationsQuerySchema = paginationSchema
  .extend({
    userId: z.string().uuid().optional(),
    locationId: z.string().uuid().optional(),
    status: z.enum(AUTHORIZATION_QUERY_STATUS).optional(),
    from: dateOnlySchema.optional(), // período que intersecta [from, to]
    to: dateOnlySchema.optional(),
  })
  .refine((v) => !v.from || !v.to || v.to >= v.from, {
    message: "'to' deve ser igual ou posterior a 'from'",
    path: ["to"],
  });

export type CreateAuthorizationDto = z.infer<typeof createAuthorizationSchema>;
export type CancelAuthorizationDto = z.infer<typeof cancelAuthorizationSchema>;
export type ListAuthorizationsQuery = z.infer<typeof listAuthorizationsQuerySchema>;
