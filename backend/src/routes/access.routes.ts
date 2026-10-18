import { Router } from "express";
import { asyncHandler as h } from "../middlewares/error.middleware.js";
import { authenticate } from "../middlewares/auth.middleware.js";
import { rateLimit } from "../middlewares/rate-limit.middleware.js";
import * as qrAccess from "../controllers/qr-access.controller.js";

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
