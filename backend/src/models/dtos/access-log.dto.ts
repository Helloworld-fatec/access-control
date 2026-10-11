// backend/src/models/dtos/access-log.dto.ts
import { z } from "zod";
import {
  ACCESS_METHODS,
  ACCESS_RESULTS,
  type AccessMethod,
  type AccessResult,
} from "../../types/index";
import { dateOnlySchema, paginationSchema } from "./common.dto";

const methods = Object.values(ACCESS_METHODS) as [AccessMethod, ...AccessMethod[]];
const results = Object.values(ACCESS_RESULTS) as [AccessResult, ...AccessResult[]];

export const listAccessLogsQuerySchema = paginationSchema
  .extend({
    userId: z.string().uuid().optional(),
    terminalId: z.string().uuid().optional(),
    method: z.enum(methods).optional(),
    result: z.enum(results).optional(),
    from: dateOnlySchema.optional(),
    to: dateOnlySchema.optional(),
  })
  .refine((v) => !v.from || !v.to || v.to >= v.from, {
    message: "'to' deve ser igual ou posterior a 'from'",
    path: ["to"],
  });

export type ListAccessLogsQuery = z.infer<typeof listAccessLogsQuerySchema>;
