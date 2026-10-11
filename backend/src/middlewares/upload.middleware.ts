// backend/src/middlewares/upload.middleware.ts
import fs from "node:fs";
import path from "node:path";
import { randomUUID } from "node:crypto";
import type { RequestHandler } from "express";
import multer from "multer";
import { env } from "../config/env.js";
import { ensurePhotosDir, removePhotoFile } from "../config/photos.js";
import { AppError } from "./error.middleware.js";

/** Nome do campo do arquivo no multipart/form-data. */
export const PHOTO_FIELD = "photo";

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    ensurePhotosDir(); // garante a pasta mesmo que o servidor tenha subido sem ela
    cb(null, env.PHOTOS_DIR);
  },
  // Nome sempre gerado aqui (UUID): nunca usa o nome enviado pelo cliente.
  filename: (_req, _file, cb) => {
    cb(null, `${randomUUID()}.jpg`);
  },
});

const parseMultipart = multer({
  storage,
  limits: {
    fileSize: env.MAX_PHOTO_BYTES, // estoura -> MulterError LIMIT_FILE_SIZE (413)
    files: 1,
    fields: 10,
    fieldSize: 64 * 1024, // o embedding (128 floats em JSON) tem poucos KB
  },
  // Filtro rápido pelo tipo declarado. O conteúdo real é verificado em verifyJpeg.
  fileFilter: (_req, file, cb) => {
    if (file.mimetype !== "image/jpeg") {
      cb(new AppError(415, "A foto deve ser um arquivo JPEG", "UNSUPPORTED_MEDIA_TYPE"));
      return;
    }
    cb(null, true);
  },
}).single(PHOTO_FIELD);

/** Confere os bytes iniciais do arquivo: todo JPEG começa com FF D8 FF. */
const verifyJpeg: RequestHandler = async (req, _res, next) => {
  const file = req.file;
  if (!file) return next();

  try {
    const handle = await fs.promises.open(path.join(file.destination, file.filename), "r");
    let isJpeg = false;
    try {
      const header = Buffer.alloc(3);
      const { bytesRead } = await handle.read(header, 0, 3, 0);
      isJpeg =
        bytesRead === 3 && header[0] === 0xff && header[1] === 0xd8 && header[2] === 0xff;
    } finally {
      await handle.close();
    }

    if (!isJpeg) {
      throw new AppError(
        415,
        "O arquivo enviado não é um JPEG válido",
        "UNSUPPORTED_MEDIA_TYPE",
      );
    }
    next();
  } catch (err) {
    await removePhotoFile(file.filename); // não deixa arquivo inválido no disco
    next(err);
  }
};

/**
 * Upload de uma foto (campo "photo", opcional). Use nas rotas multipart:
 *   router.post("/:id/face", uploadPhoto, handler)
 * Depois dele, req.file (se enviado) já está salvo em PHOTOS_DIR e validado,
 * e os demais campos de texto estão em req.body.
 */
export const uploadPhoto: RequestHandler[] = [parseMultipart, verifyJpeg];
