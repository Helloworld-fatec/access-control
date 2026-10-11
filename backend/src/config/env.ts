// backend/src/config/env.ts
import "dotenv/config";
import path from "node:path";
import { z } from "zod";

const envSchema = z.object({
  PORT: z.coerce.number().int().positive().default(3000),
  DATABASE_URL: z.string().min(1, "DATABASE_URL é obrigatória"),
  /** Pasta das fotos. Relativa ao diretório de execução (backend/). */
  PHOTOS_DIR: z.string().min(1).default("photos"),
  BCRYPT_ROUNDS: z.coerce.number().int().min(4).max(15).default(10),
  /** Limite do upload (100 KB: folga sobre os ~50 KB da foto reduzida). */
  MAX_PHOTO_BYTES: z.coerce.number().int().positive().default(100 * 1024),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error("Variáveis de ambiente inválidas:");
  for (const issue of parsed.error.issues) {
    console.error(`  - ${issue.path.join(".")}: ${issue.message}`);
  }
  process.exit(1);
}

export const env = {
  ...parsed.data,
  PHOTOS_DIR: path.resolve(parsed.data.PHOTOS_DIR),
};
