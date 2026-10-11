// backend/src/routes/index.ts
import { Router } from "express";
import { userRoutes } from "./user.routes.js";
import { locationRoutes } from "./location.routes.js";
import { terminalRoutes } from "./terminal.routes.js";
import { authorizationRoutes } from "./authorization.routes.js";
import { accessLogRoutes } from "./access-log.routes.js";

export const routes = Router();

routes.get("/health", (_req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

routes.use("/users", userRoutes);
routes.use("/locations", locationRoutes);
routes.use("/terminals", terminalRoutes);
routes.use("/authorizations", authorizationRoutes);
routes.use("/access-logs", accessLogRoutes);
