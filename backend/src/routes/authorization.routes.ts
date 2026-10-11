// backend/src/routes/authorization.routes.ts
import { Router } from "express";
import { asyncHandler as h } from "../middlewares/error.middleware.js";
import * as authorizations from "../controllers/authorizations.controller.js";

export const authorizationRoutes = Router();

authorizationRoutes.get("/", h(authorizations.listAuthorizations));
authorizationRoutes.post("/", h(authorizations.createAuthorization));
authorizationRoutes.get("/:id", h(authorizations.getAuthorization));
authorizationRoutes.patch("/:id/cancel", h(authorizations.cancelAuthorization));
