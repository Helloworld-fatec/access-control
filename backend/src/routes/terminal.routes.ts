// backend/src/routes/terminal.routes.ts
import { Router } from "express";
import { asyncHandler as h } from "../middlewares/error.middleware.js";
import { authenticateTerminal, limitTerminalAuth } from "../middlewares/terminal-auth.middleware.js";
import { authenticate, requireAdmin as requireActiveAdmin } from "../middlewares/auth.middleware.js";
import { requireAdmin } from "../middlewares/admin.middleware.js";
import { rateLimit } from "../middlewares/rate-limit.middleware.js";
import * as terminals from "../controllers/terminals.controller.js";
import * as qrAccess from "../controllers/qr-access.controller.js";

export const terminalRoutes = Router();

terminalRoutes.get("/me", limitTerminalAuth, authenticateTerminal, (req, res) => {
  res.json({ id: req.terminal!.id });
});

// O QR usa a credencial do terminal; o gerenciamento exige JWT de administrador.
terminalRoutes.post(
  "/me/qr",
  limitTerminalAuth,
  authenticateTerminal,
  rateLimit({ windowMs: 60_000, max: 30, key: (req) => `terminal:${req.terminal?.id ?? req.ip}` }),
  h(qrAccess.issueQr),
);

// Operações do equipamento autenticadas pela API key do próprio terminal.
terminalRoutes.get("/:id/qr", limitTerminalAuth, authenticateTerminal, h(terminals.getTerminalQr));
terminalRoutes.get("/:id/status", limitTerminalAuth, authenticateTerminal, h(terminals.getTerminalStatus));
terminalRoutes.get(
  "/:id/faces",
  limitTerminalAuth,
  authenticateTerminal,
  h(terminals.getTerminalFaces),
);

terminalRoutes.get("/status", authenticate, requireActiveAdmin, h(terminals.listTerminalStatus));
terminalRoutes.use(authenticate, requireAdmin);
terminalRoutes.get("/", h(terminals.listTerminals));
terminalRoutes.post("/", h(terminals.createTerminal));
terminalRoutes.post("/:id/rotate-key", h(terminals.rotateTerminalKey));
terminalRoutes.get("/:id", h(terminals.getTerminal));
terminalRoutes.put("/:id", h(terminals.updateTerminal));
terminalRoutes.delete("/:id", h(terminals.deleteTerminal));
