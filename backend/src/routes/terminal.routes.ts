// backend/src/routes/terminal.routes.ts
import { Router } from "express";
import { asyncHandler as h } from "../middlewares/error.middleware.js";
import { requireTerminalAuth } from "../middlewares/terminal-auth.middleware.js";
import * as terminals from "../controllers/terminals.controller.js";

export const terminalRoutes = Router();

terminalRoutes.get("/", h(terminals.listTerminals));
terminalRoutes.post("/", h(terminals.createTerminal));
terminalRoutes.get("/:id", h(terminals.getTerminal));
terminalRoutes.put("/:id", h(terminals.updateTerminal));
terminalRoutes.delete("/:id", h(terminals.deleteTerminal));

// Operação do Terminal de Acesso (mobile-readings)
terminalRoutes.get("/:id/qr", requireTerminalAuth, h(terminals.getTerminalQr));
terminalRoutes.get("/:id/status", h(terminals.getTerminalStatus));
terminalRoutes.get(
  "/:id/faces",
  requireTerminalAuth,
  h(terminals.getTerminalFaces),
);
