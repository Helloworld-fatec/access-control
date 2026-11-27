import { Router } from "express";
import { asyncHandler as h } from "../middlewares/error.middleware.js";
import { authenticate } from "../middlewares/auth.middleware.js";
import { rateLimit } from "../middlewares/rate-limit.middleware.js";
import * as qrAccess from "../controllers/qr-access.controller.js";
import * as access from "../controllers/access.controller.js";
import { authenticateTerminal, limitTerminalAuth } from "../middlewares/terminal-auth.middleware.js";
import { uploadFaceCapture } from "../middlewares/upload.middleware.js";

export const accessRoutes = Router();

accessRoutes.post(
  "/qr/consume",
  authenticate,
  rateLimit({
    windowMs: 60_000,
    max: 20,
    key: (req) => `user:${req.auth?.userId ?? "unknown"}:ip:${req.ip}`,
  }),
  h(qrAccess.consumeQr),
);

accessRoutes.post("/nfc", limitTerminalAuth, authenticateTerminal, h(access.validateNfcAccess));
accessRoutes.post(
  "/face/capture",
  limitTerminalAuth,
  authenticateTerminal,
  rateLimit({ windowMs: 60_000, max: 20, key: (req) => `face:${req.terminal?.id ?? req.ip}` }),
  uploadFaceCapture,
  h(access.validateFaceCapture),
);
accessRoutes.post("/face", limitTerminalAuth, authenticateTerminal, h(access.validateFaceAccess));
