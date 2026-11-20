// backend/src/models/dtos/face.dto.ts
import { z } from "zod";

/** Tamanho do vetor gerado pelo modelo TFLite (ex.: MobileFaceNet = 128). */
export const EMBEDDING_SIZE = 128;

/**
 * POST /users/:id/face é multipart/form-data. Campos de texto chegam como
 * string, então o embedding vem como JSON ("[0.12, -0.03, ...]") e o
 * consentimento como "true". A foto chega como arquivo (multer, campo "photo").
 */
const embeddingField = z.preprocess(
  (v) => {
    if (typeof v !== "string") return v;
    try {
      return JSON.parse(v);
    } catch {
      return null;
    }
  },
  z
    .array(z.number().finite(), { message: "Embedding deve ser um array JSON de números" })
    .length(EMBEDDING_SIZE, `Embedding deve ter ${EMBEDDING_SIZE} valores`),
);

const consentField = z
  .union([z.boolean(), z.enum(["true", "false"])])
  .transform((v) => v === true || v === "true")
  .refine((v) => v === true, "É necessário o consentimento do usuário (LGPD)");

export const upsertFaceSchema = z.object({
  embedding: embeddingField,
  modelVersion: z.string().trim().min(1).max(50),
  consent: consentField,
});

export type UpsertFaceDto = z.infer<typeof upsertFaceSchema>;
