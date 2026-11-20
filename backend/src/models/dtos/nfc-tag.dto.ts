// backend/src/models/dtos/nfc-tag.dto.ts
import { z } from "zod";

/**
 * Padroniza o UID: hexadecimal em maiúsculas, sem separadores.
 * "04:a3:2f:1b" -> "04A32F1B". O mobile-registry e o mobile-readings
 * devem enviar o mesmo formato, mas o backend normaliza por segurança.
 */
export const nfcUidSchema = z
  .string()
  .trim()
  .transform((v) => v.replace(/[\s:-]/g, "").toUpperCase())
  .pipe(
    z
      .string()
      .regex(/^[0-9A-F]+$/, "UID deve ser hexadecimal")
      .min(8, "UID muito curto")
      .max(20, "UID muito longo"),
  );

export const createNfcTagSchema = z.object({
  uid: nfcUidSchema,
});

export const nfcTagParamsSchema = z.object({
  id: z.string().uuid("ID inválido"),
  tagId: z.string().uuid("ID da tag inválido"),
});

export type CreateNfcTagDto = z.infer<typeof createNfcTagSchema>;
