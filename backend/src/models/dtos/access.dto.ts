// backend/src/models/dtos/access.dto.ts
import { z } from "zod";
import { nfcUidSchema } from "./nfc-tag.dto.js";

export const nfcAccessSchema = z.object({
  terminalId: z.string().uuid("terminalId inválido"),
  uid: nfcUidSchema,
});

export const esp32NfcAccessSchema = z.object({
  terminalId: z.uuid(),
  credential: z.object({
    type: z.literal("NFC"),
    value: z.string().regex(/^[0-9A-Fa-f]{6}$/).transform((value) => value.toUpperCase()),
  }),
});

export const faceAccessSchema = z.object({
  terminalId: z.string().uuid("terminalId inválido"),
  userId: z.string().uuid("userId inválido"),
  confidence: z
    .number()
    .min(0, "Confiança mínima é 0")
    .max(1, "Confiança máxima é 1"),
});

export type NfcAccessDto = z.infer<typeof nfcAccessSchema>;
export type FaceAccessDto = z.infer<typeof faceAccessSchema>;
