// backend/src/routes/access-log.routes.ts
import { Router } from "express";
import { asyncHandler as h } from "../middlewares/error.middleware.js";
import * as accessLogs from "../controllers/access-logs.controller.js";

export const accessLogRoutes = Router();

accessLogRoutes.get("/", h(accessLogs.listAccessLogs));
