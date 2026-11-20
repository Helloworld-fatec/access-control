import { Router } from "express";
import { login } from "../controllers/auth.controller.js";
import { asyncHandler as h } from "../middlewares/error.middleware.js";

export const authRoutes = Router();
authRoutes.post("/", h(login));
