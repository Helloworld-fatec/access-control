// backend/src/routes/authorization.routes.ts
import { Router } from "express";
import { asyncHandler as h } from "../middlewares/error.middleware.js";
import { authenticate, requireAdmin } from "../middlewares/auth.middleware.js";
import * as authorizations from "../controllers/authorizations.controller.js";

export const authorizationRoutes = Router();

authorizationRoutes.use(authenticate);
authorizationRoutes.get("/me", h(authorizations.listMyAuthorizations));
authorizationRoutes.use(requireAdmin);
authorizationRoutes.get("/", h(authorizations.listAuthorizations));
authorizationRoutes.post("/", h(authorizations.createAuthorization));
authorizationRoutes.get("/:id", h(authorizations.getAuthorization));
authorizationRoutes.patch("/:id/cancel", h(authorizations.cancelAuthorization));
