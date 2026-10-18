// backend/src/routes/terminal.routes.ts
import { Router } from "express";
import { asyncHandler as h } from "../middlewares/error.middleware.js";
import { authenticateTerminal } from "../middlewares/terminal-auth.middleware.js";
import { authenticate } from "../middlewares/auth.middleware.js";
import { requireAdmin } from "../middlewares/admin.middleware.js";
import { rateLimit } from "../middlewares/rate-limit.middleware.js";
import * as terminals from "../controllers/terminals.controller.js";
import * as qrAccess from "../controllers/qr-access.controller.js";

export const terminalRoutes = Router();

// O QR usa a credencial do terminal; o gerenciamento exige JWT de administrador.
terminalRoutes.post(
  "/me/qr",
  authenticateTerminal,
  rateLimit({ windowMs: 60_000, max: 30, key: (req) => `terminal:${req.terminal?.id ?? req.ip}` }),
  h(qrAccess.issueQr),
);

terminalRoutes.use(authenticate, requireAdmin);
terminalRoutes.get("/", h(terminals.listTerminals));
terminalRoutes.post("/", h(terminals.createTerminal));
terminalRoutes.get("/:id", h(terminals.getTerminal));
terminalRoutes.put("/:id", h(terminals.updateTerminal));
terminalRoutes.delete("/:id", h(terminals.deleteTerminal));
