import type { RequestHandler } from "express";
import multer from "multer";
import { env } from "../config/env.js";
import { AppError } from "./error.middleware.js";

const parsePhoto = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: env.MAX_PHOTO_BYTES + 1, files: 1, fields: 1, fieldSize: 16 },
  fileFilter: (_req, file, cb) => {
    if (file.mimetype !== "image/jpeg") {
      cb(new AppError(415, "A foto deve ser um arquivo JPEG", "UNSUPPORTED_MEDIA_TYPE"));
      return;
    }
    cb(null, true);
  },
}).single("photo");

export const uploadFacePhoto: RequestHandler = (req, res, next) => {
  if (!req.is("multipart/form-data")) {
    next(new AppError(415, "Envie a foto em multipart/form-data", "UNSUPPORTED_MEDIA_TYPE"));
    return;
  }

  parsePhoto(req, res, (err: unknown) => {
    if (err) {
      next(
        err instanceof multer.MulterError || err instanceof AppError
          ? err
          : new AppError(400, "Falha no upload do arquivo", "UPLOAD_ERROR"),
      );
      return;
    }
    const photo = req.file?.buffer;
    if (!photo) {
      next(new AppError(400, "A foto é obrigatória", "PHOTO_REQUIRED"));
    } else if (photo.length > env.MAX_PHOTO_BYTES) {
      next(new AppError(413, "Arquivo maior que o limite permitido", "FILE_TOO_LARGE"));
    } else if (photo[0] !== 0xff || photo[1] !== 0xd8 || photo[2] !== 0xff) {
      next(new AppError(415, "O arquivo enviado não é um JPEG válido", "UNSUPPORTED_MEDIA_TYPE"));
    } else {
      next();
    }
  });
};
