import { z } from "zod";
import { env } from "../config/env.js";
import { AppError } from "../middlewares/error.middleware.js";

export const FACE_MODEL_VERSION = "hog-v1";
export const MAX_FACE_CANDIDATES = 256;
export const MAX_FACE_CAPTURES = 3;
const FACE_VECTOR_SIZE = 1764;
const MINIMUM_SCORE = 0.75;
const MINIMUM_MARGIN = 0.08;

const extractionSchema = z.object({
  embedding: z.array(z.number().finite()).length(FACE_VECTOR_SIZE),
  modelVersion: z.literal(FACE_MODEL_VERSION),
});

const extractionErrorSchema = z.object({
  detail: z.object({
    code: z.enum([
      "CORRUPT_IMAGE",
      "PHOTO_TOO_LARGE",
      "NO_FACE",
      "MULTIPLE_FACES",
      "IMAGE_DIMENSIONS_TOO_LARGE",
      "UNSUPPORTED_IMAGE_TYPE",
    ]),
  }),
});

const photoErrors = {
  PHOTO_TOO_LARGE: [413, "A foto excede o limite permitido"],
  CORRUPT_IMAGE: [422, "A foto enviada está corrompida"],
  NO_FACE: [422, "Nenhum rosto foi encontrado na foto"],
  MULTIPLE_FACES: [422, "A foto deve conter apenas um rosto"],
  IMAGE_DIMENSIONS_TOO_LARGE: [413, "As dimensões da foto excedem o limite permitido"],
  UNSUPPORTED_IMAGE_TYPE: [415, "A foto deve ser um arquivo JPEG"],
} as const;

export async function extractFace(photo: Buffer) {
  const form = new FormData();
  form.set("photo", new Blob([new Uint8Array(photo)], { type: "image/jpeg" }), "photo.jpg");
  const body = await callFaceService("/extract", form);
  const result = extractionSchema.safeParse(body);
  if (!result.success) throw invalidResponse();
  return result.data;
}

const matchSchema = z.discriminatedUnion("result", [
  z.object({
    result: z.literal("MATCH"),
    userId: z.string().min(1),
    score: z.number().finite().min(MINIMUM_SCORE).max(1),
  }),
  z.object({ result: z.literal("UNKNOWN_FACE") }),
  z.object({ result: z.literal("AMBIGUOUS_FACE") }),
]);

interface FaceCandidate {
  userId: string;
  embedding: number[];
}

export function isCompatibleFaceEmbedding(embedding: number[]): boolean {
  return embedding.length === FACE_VECTOR_SIZE &&
    embedding.every((value) => Number.isFinite(value) && value >= 0 && value <= 1) &&
    embedding.some((value) => value > 0);
}

export async function matchFace(photos: Buffer[], candidates: FaceCandidate[]) {
  const body = await callFaceService("/match", JSON.stringify({
    photos: photos.map((photo) => photo.toString("base64")),
    candidates: candidates.map((candidate) => ({ ...candidate, modelVersion: FACE_MODEL_VERSION })),
    minimumScore: MINIMUM_SCORE,
    minimumMargin: MINIMUM_MARGIN,
  }));
  const result = matchSchema.safeParse(body);
  if (!result.success) throw invalidResponse();
  const match = result.data;
  if (match.result === "MATCH" && !candidates.some(({ userId }) => userId === match.userId)) {
    throw invalidResponse();
  }
  return match;
}

const invalidResponse = () =>
  new AppError(502, "Resposta inválida do serviço facial", "FACE_SERVICE_INVALID_RESPONSE");

async function callFaceService(path: string, payload: FormData | string): Promise<unknown> {
  const signal = AbortSignal.timeout(env.FACE_RECOGNITION_TIMEOUT_MS);
  const timeout = () =>
    new AppError(504, "O serviço facial demorou para responder", "FACE_SERVICE_TIMEOUT");
  const unavailable = () =>
    new AppError(502, "Serviço facial indisponível", "FACE_SERVICE_UNAVAILABLE");

  let response: Response;
  try {
    response = await fetch(new URL(path, env.FACE_RECOGNITION_URL), {
      method: "POST",
      body: payload,
      ...(typeof payload === "string" ? { headers: { "content-type": "application/json" } } : {}),
      signal,
      redirect: "error",
    });
  } catch {
    throw signal.aborted ? timeout() : unavailable();
  }

  if (response.status >= 500 && path === "/match") throw unavailable();

  let body: unknown;
  try {
    body = await response.json();
  } catch {
    throw signal.aborted ? timeout() : invalidResponse();
  }

  if (response.status === 200) return body;
  const result = extractionErrorSchema.safeParse(body);
  if (result.success) {
    const { code } = result.data.detail;
    const [status, message] = photoErrors[code];
    if (response.status === status) throw new AppError(status, message, code);
  }
  throw invalidResponse();
}
