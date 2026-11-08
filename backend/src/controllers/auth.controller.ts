import type { Request, Response } from "express";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import { prisma } from "../config/prisma.js";
import { env } from "../config/env.js";
import { AppError } from "../middlewares/error.middleware.js";
import { loginSchema } from "../models/dtos/auth.dto.js";
import { toUserResponse } from "../models/user.model.js";

export async function login(req: Request, res: Response) {
  const { email, password } = loginSchema.parse(req.body);
  const user = await prisma.user.findUnique({ where: { email } });

  if (!user || !user.active || !(await bcrypt.compare(password, user.passwordHash))) {
    throw new AppError(401, "E-mail ou senha inválidos", "INVALID_CREDENTIALS");
  }

  const accessToken = jwt.sign(
    { role: user.role },
    env.JWT_SECRET,
    { subject: user.id, expiresIn: env.JWT_EXPIRES_IN as jwt.SignOptions["expiresIn"] },
  );

  res.json({
    accessToken,
    tokenType: "Bearer",
    expiresIn: env.JWT_EXPIRES_IN,
    user: toUserResponse(user),
  });
}
