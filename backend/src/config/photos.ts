// backend/src/config/photos.ts
import fs from "node:fs";
import path from "node:path";
import { env } from "./env";

/** Cria a pasta de fotos se ela não existir. Chamada na subida do servidor. */
export function ensurePhotosDir(): void {
  fs.mkdirSync(env.PHOTOS_DIR, { recursive: true });
}

/**
 * Converte um caminho relativo (o que fica no banco) em caminho absoluto,
 * garantindo que continua dentro de PHOTOS_DIR (proteção contra path traversal).
 */
export function resolvePhotoPath(relativePath: string): string {
  const base = env.PHOTOS_DIR;
  const full = path.resolve(base, relativePath);
  if (!full.startsWith(base + path.sep)) {
    throw new Error("Caminho de foto inválido");
  }
  return full;
}

/** Apaga o arquivo da foto. Ignora se ele já não existir. */
export async function removePhotoFile(
  relativePath: string | null | undefined,
): Promise<void> {
  if (!relativePath) return;
  try {
    await fs.promises.unlink(resolvePhotoPath(relativePath));
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code !== "ENOENT") {
      console.error("Falha ao remover foto:", err);
    }
  }
}
