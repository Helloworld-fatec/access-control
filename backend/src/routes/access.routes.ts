// backend/src/routes/access.routes.ts
import { Router } from "express";
import { asyncHandler as h } from "../middlewares/error.middleware.js";
import { requireTerminalAuth } from "../middlewares/terminal-auth.middleware.js";
import * as access from "../controllers/access.controller.js";

export const accessRoutes = Router();

accessRoutes.post("/nfc", requireTerminalAuth, h(access.validateNfcAccess));
accessRoutes.post("/face", requireTerminalAuth, h(access.validateFaceAccess));
