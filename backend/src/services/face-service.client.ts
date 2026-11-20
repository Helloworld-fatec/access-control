import fs from "node:fs";
import path from "node:path";
import { env } from "../config/env.js";
import { prisma } from "../config/prisma.js";

const FACE_SERVICE_BASE_URL = process.env.FACE_SERVICE_URL || "http://127.0.0.1:8000";

export interface FaceMatchResponse {
  enrolled: boolean;
  faces: Array<{
    box: [number, number, number, number];
    score: number;
    match: boolean;
    userId?: string | null;
    userName?: string | null;
  }>;
}

/**
 * Envia uma foto para cadastro biométrico HOG no microserviço Python.
 */
export async function enrollUserInFaceService(
  userId: string,
  userName: string,
  photoBuffer: Buffer,
): Promise<boolean> {
  try {
    const url = `${FACE_SERVICE_BASE_URL}/api/enroll?userId=${encodeURIComponent(userId)}&name=${encodeURIComponent(userName)}`;
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "image/jpeg" },
      body: photoBuffer,
    });
    return res.ok;
  } catch (e) {
    console.warn(`[FaceServiceClient] Falha ao cadastrar rosto do usuário ${userId}:`, e);
    return false;
  }
}

/**
 * Compara um frame/foto recebido do terminal contra todos os usuários cadastrados no serviço HOG.
 */
export async function matchFaceInService(
  photoBuffer: Buffer,
  threshold = 0.50,
): Promise<FaceMatchResponse | null> {
  try {
    const url = `${FACE_SERVICE_BASE_URL}/api/match?threshold=${threshold}`;
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "image/jpeg" },
      body: photoBuffer,
    });
    if (!res.ok) return null;
    return (await res.json()) as FaceMatchResponse;
  } catch (e) {
    console.warn("[FaceServiceClient] Erro ao consultar match facial no serviço Python:", e);
    return null;
  }
}

/**
 * Sincroniza todas as fotos de usuários salvas no banco com o microserviço Python HOG.
 */
export async function syncDatabasePhotosToFaceService(): Promise<number> {
  try {
    const photos = await prisma.userPhoto.findMany({
      include: {
        user: { select: { id: true, name: true, active: true } },
      },
    });

    let enrolledCount = 0;
    for (const item of photos) {
      if (!item.user.active) continue;
      const fullPath = path.resolve(env.PHOTOS_DIR, item.filePath);
      if (!fs.existsSync(fullPath)) continue;

      const buffer = fs.readFileSync(fullPath);
      const ok = await enrollUserInFaceService(item.user.id, item.user.name, buffer);
      if (ok) enrolledCount++;
    }

    if (enrolledCount > 0) {
      console.log(`[FaceServiceClient] ${enrolledCount} usuários sincronizados com o serviço HOG.`);
    }
    return enrolledCount;
  } catch (e) {
    console.warn("[FaceServiceClient] Falha ao sincronizar fotos locais:", e);
    return 0;
  }
}
