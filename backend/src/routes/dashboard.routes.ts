// backend/src/routes/dashboard.routes.ts
import { Router } from "express";
import { asyncHandler as h } from "../middlewares/error.middleware.js";
import { authenticate } from "../middlewares/auth.middleware.js";
import { requireAdmin } from "../middlewares/admin.middleware.js";
import * as dashboard from "../controllers/dashboard.controller.js";

export const dashboardRoutes = Router();

// Os indicadores são dados de gestão: só o administrador vê.
dashboardRoutes.use(authenticate, requireAdmin);
dashboardRoutes.get("/summary", h(dashboard.getSummary));
dashboardRoutes.get("/accesses-by-hour", h(dashboard.getAccessesByHour));
