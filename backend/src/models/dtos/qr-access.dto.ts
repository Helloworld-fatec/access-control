import { z } from "zod";

export const consumeQrSchema = z.object({
  token: z.string().regex(/^(?:[A-Za-z0-9_-]{43}|Q[A-Z0-9]{19})$/, "Token QR inválido"),
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
});

export type ConsumeQrDto = z.infer<typeof consumeQrSchema>;
