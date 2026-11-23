// backend/src/models/dtos/access.dto.ts
import { z } from "zod";
import { nfcUidSchema } from "./nfc-tag.dto.js";

export const nfcAccessSchema = z.object({
  terminalId: z.string().uuid("terminalId inválido"),
  uid: nfcUidSchema,
});

export const esp32NfcAccessSchema = z.object({
  terminalId: z.uuid(),
  uid: nfcUidSchema.refine((uid) => [8, 14, 20].includes(uid.length)),
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
