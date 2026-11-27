// backend/src/routes/access-log.routes.ts
import { Router } from "express";
import { authenticate, requireAdmin } from "../middlewares/auth.middleware.js";
import { asyncHandler as h } from "../middlewares/error.middleware.js";
import { authenticate } from "../middlewares/auth.middleware.js";
import { requireAdmin } from "../middlewares/admin.middleware.js";
import * as accessLogs from "../controllers/access-logs.controller.js";

export const accessLogRoutes = Router();

accessLogRoutes.use(authenticate, requireAdmin);
accessLogRoutes.get("/", h(accessLogs.listAccessLogs));

// A exportação leva dados pessoais para fora do sistema: exige token de administrador mesmo com a listagem aberta.
accessLogRoutes.get("/export", authenticate, requireAdmin, h(accessLogs.exportAccessLogs));
