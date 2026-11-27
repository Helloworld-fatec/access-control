import type { RequestHandler } from "express";
import multer from "multer";
import { env } from "../config/env.js";
import { MAX_FACE_CAPTURES } from "../services/face-recognition.service.js";
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

const parseCapture = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: env.MAX_PHOTO_BYTES + 1, files: MAX_FACE_CAPTURES, fields: 0 },
  fileFilter: (_req, file, cb) => {
    if (file.mimetype !== "image/jpeg") {
      cb(new AppError(415, "Envie imagens JPEG", "UNSUPPORTED_IMAGE_TYPE"));
      return;
    }
    cb(null, true);
  },
}).array("photos", MAX_FACE_CAPTURES);

export const uploadFaceCapture: RequestHandler = (req, res, next) => {
  if (!req.is("multipart/form-data")) {
    next(new AppError(415, "Envie as imagens em multipart/form-data", "UNSUPPORTED_MEDIA_TYPE"));
    return;
  }
  const maxRequestBytes = MAX_FACE_CAPTURES * env.MAX_PHOTO_BYTES + 16_384;
  if (Number(req.get("content-length")) > maxRequestBytes) {
    next(new AppError(413, "A captura excede o limite permitido", "REQUEST_TOO_LARGE"));
    return;
  }

  parseCapture(req, res, (err: unknown) => {
    if (err) {
      next(
        err instanceof multer.MulterError || err instanceof AppError
          ? err
          : new AppError(400, "Falha no upload da captura", "UPLOAD_ERROR"),
      );
      return;
    }
    const files = req.files;
    if (!Array.isArray(files) || files.length === 0) {
      next(new AppError(400, "Envie ao menos uma imagem", "PHOTO_REQUIRED"));
    } else if (files.some(({ size }) => size > env.MAX_PHOTO_BYTES)) {
      next(new AppError(413, "A imagem excede o limite permitido", "PHOTO_TOO_LARGE"));
    } else {
      next();
    }
  });
};
