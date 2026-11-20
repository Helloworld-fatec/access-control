import { z } from "zod";
import { env } from "../config/env.js";
import { AppError } from "../middlewares/error.middleware.js";

const extractionSchema = z.object({
  embedding: z.array(z.number().finite()).length(1764),
  modelVersion: z.literal("hog-v1"),
});

const extractionErrorSchema = z.object({
  detail: z.object({
    code: z.enum([
      "CORRUPT_IMAGE",
      "NO_FACE",
      "MULTIPLE_FACES",
      "IMAGE_DIMENSIONS_TOO_LARGE",
      "UNSUPPORTED_IMAGE_TYPE",
    ]),
  }),
});

const photoErrors = {
  CORRUPT_IMAGE: [422, "A foto enviada está corrompida"],
  NO_FACE: [422, "Nenhum rosto foi encontrado na foto"],
  MULTIPLE_FACES: [422, "A foto deve conter apenas um rosto"],
  IMAGE_DIMENSIONS_TOO_LARGE: [413, "As dimensões da foto excedem o limite permitido"],
  UNSUPPORTED_IMAGE_TYPE: [415, "A foto deve ser um arquivo JPEG"],
} as const;

export async function extractFace(photo: Buffer) {
  const form = new FormData();
  form.set("photo", new Blob([new Uint8Array(photo)], { type: "image/jpeg" }), "photo.jpg");
  const signal = AbortSignal.timeout(env.FACE_RECOGNITION_TIMEOUT_MS);
  const invalidResponse = () =>
    new AppError(502, "Resposta inválida do serviço facial", "FACE_SERVICE_INVALID_RESPONSE");

  let response: Response;
  try {
    response = await fetch(new URL("/extract", env.FACE_RECOGNITION_URL), {
      method: "POST",
      body: form,
      signal,
      redirect: "error",
    });
  } catch {
    if (signal.aborted) {
      throw new AppError(504, "O serviço facial demorou para responder", "FACE_SERVICE_TIMEOUT");
    }
    throw new AppError(502, "Serviço facial indisponível", "FACE_SERVICE_UNAVAILABLE");
  }

  let body: unknown;
  try {
    body = await response.json();
  } catch {
    if (signal.aborted) {
      throw new AppError(504, "O serviço facial demorou para responder", "FACE_SERVICE_TIMEOUT");
    }
    throw invalidResponse();
  }

  if (response.status === 200) {
    const result = extractionSchema.safeParse(body);
    if (result.success) return result.data;
  } else {
    const result = extractionErrorSchema.safeParse(body);
    if (result.success) {
      const { code } = result.data.detail;
      const [status, message] = photoErrors[code];
      if (response.status === status) throw new AppError(status, message, code);
    }
  }
  throw invalidResponse();
}
