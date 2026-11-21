// backend/src/models/dtos/dashboard.dto.ts
import { z } from "zod";
import { dateOnlySchema } from "./common.dto.js";

/** `date` é opcional: sem ele, usa o dia de hoje em São Paulo. */
export const dashboardQuerySchema = z.object({
  date: dateOnlySchema.optional(),
});

export type DashboardQuery = z.infer<typeof dashboardQuerySchema>;
