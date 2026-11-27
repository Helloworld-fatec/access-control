import { Router } from "express";
import { authenticate, requireAdmin } from "../middlewares/auth.middleware.js";
import { asyncHandler as h } from "../middlewares/error.middleware.js";
import * as dashboard from "../controllers/dashboard.controller.js";

export const dashboardRoutes = Router();

dashboardRoutes.use(authenticate, requireAdmin);
dashboardRoutes.get("/summary", h(dashboard.summary));
dashboardRoutes.get("/accesses-by-hour", h(dashboard.accessesByHour));
