// backend/src/routes/location.routes.ts
import { Router } from "express";
import { asyncHandler as h } from "../middlewares/error.middleware.js";
import * as locations from "../controllers/locations.controller.js";

export const locationRoutes = Router();

locationRoutes.get("/", h(locations.listLocations));
locationRoutes.post("/", h(locations.createLocation));
locationRoutes.get("/:id", h(locations.getLocation));
locationRoutes.put("/:id", h(locations.updateLocation));
locationRoutes.delete("/:id", h(locations.deleteLocation));
