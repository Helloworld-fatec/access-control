// backend/src/routes/user.routes.ts
import { Router } from "express";
import { asyncHandler as h } from "../middlewares/error.middleware.js";
import { authenticate, requireAdmin } from "../middlewares/auth.middleware.js";
import { uploadFacePhoto } from "../middlewares/upload.middleware.js";
import * as users from "../controllers/users.controller.js";
import { idParamSchema, paginationSchema } from "../models/dtos/common.dto.js";
import { listUserPokemon } from "../services/pokemon-draw.service.js";

export const userRoutes = Router();

userRoutes.use(authenticate);
userRoutes.get("/me/photo", h(users.getOwnPhoto));
userRoutes.use(requireAdmin);

userRoutes.get("/", h(users.listUsers));
userRoutes.post("/", h(users.createUser));
userRoutes.get("/:id", h(users.getUser));
userRoutes.put("/:id", h(users.updateUser));
userRoutes.delete("/:id", h(users.deleteUser));
userRoutes.patch("/:id/status", h(users.updateUserStatus));
userRoutes.get("/:id/pokemon", h(async (req, res) => {
  const { id } = idParamSchema.parse(req.params);
  const { page, pageSize } = paginationSchema.parse(req.query);
  res.json(await listUserPokemon(id, page, pageSize));
}));

// Tags NFC
userRoutes.post("/:id/tags", h(users.addTag));
userRoutes.delete("/:id/tags/:tagId", h(users.removeTag));
userRoutes.put("/:id/nfc-credential", h(users.linkNfcCredential));
userRoutes.post("/:id/nfc-enrollments", h(users.startNfcEnrollment));
userRoutes.get("/:id/nfc-enrollments/:requestId", h(users.getNfcEnrollment));

// Rosto e foto
// multipart/form-data: consent=true e photo (JPEG)
userRoutes.post("/:id/face", uploadFacePhoto, h(users.upsertFace));
userRoutes.delete("/:id/face", h(users.deleteFace));
userRoutes.get("/:id/photo", h(users.getPhoto));
