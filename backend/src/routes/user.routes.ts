// backend/src/routes/user.routes.ts
import { Router } from "express";
import { asyncHandler as h } from "../middlewares/error.middleware.js";
import { authenticate, requireAdmin } from "../middlewares/auth.middleware.js";
import { uploadFacePhoto } from "../middlewares/upload.middleware.js";
import * as users from "../controllers/users.controller.js";

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

// Tags NFC
userRoutes.post("/:id/tags", h(users.addTag));
userRoutes.delete("/:id/tags/:tagId", h(users.removeTag));
userRoutes.put("/:id/nfc-credential", h(users.linkNfcCredential));

// Rosto e foto
// multipart/form-data: consent=true e photo (JPEG)
userRoutes.post("/:id/face", uploadFacePhoto, h(users.upsertFace));
userRoutes.delete("/:id/face", h(users.deleteFace));
userRoutes.get("/:id/photo", h(users.getPhoto));
