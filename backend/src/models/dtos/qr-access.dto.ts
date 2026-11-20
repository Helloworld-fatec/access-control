import { z } from "zod";

export const consumeQrSchema = z.object({
  token: z.string().regex(/^[A-Za-z0-9_-]{43}$/, "Token QR inválido"),
});

export type ConsumeQrDto = z.infer<typeof consumeQrSchema>;
