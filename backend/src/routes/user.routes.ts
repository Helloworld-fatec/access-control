// backend/src/routes/user.routes.ts
import { Router } from "express";
import { asyncHandler as h } from "../middlewares/error.middleware.js";
import { uploadPhoto } from "../middlewares/upload.middleware.js";
import * as users from "../controllers/users.controller.js";

export const userRoutes = Router();

userRoutes.get("/", h(users.listUsers));
userRoutes.post("/", h(users.createUser));
userRoutes.get("/:id", h(users.getUser));
userRoutes.put("/:id", h(users.updateUser));
userRoutes.patch("/:id/status", h(users.updateUserStatus));

// Tags NFC
userRoutes.post("/:id/tags", h(users.addTag));
userRoutes.delete("/:id/tags/:tagId", h(users.removeTag));

// Rosto e foto
// multipart/form-data: embedding (JSON), modelVersion, consent e, opcional, photo (JPEG)
userRoutes.post("/:id/face", uploadPhoto, h(users.upsertFace));
userRoutes.delete("/:id/face", h(users.deleteFace));
userRoutes.get("/:id/photo", h(users.getPhoto));
