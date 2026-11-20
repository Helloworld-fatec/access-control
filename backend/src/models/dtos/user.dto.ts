// backend/src/models/dtos/user.dto.ts
import { z } from "zod";
import { USER_ROLES, type UserRole } from "../../types/index.js";
import { paginationSchema, booleanQuerySchema } from "./common.dto.js";

const roles = Object.values(USER_ROLES) as [UserRole, ...UserRole[]];
const roleSchema = z.enum(roles, { message: "Perfil inválido" });

const optionalText = (max: number) =>
  z
    .string()
    .trim()
    .max(max)
    .transform((v) => (v === "" ? undefined : v))
    .optional();

export const createUserSchema = z.object({
  name: z.string().trim().min(2, "Nome muito curto").max(120),
  document: optionalText(30),
  email: z.string().trim().toLowerCase().email("E-mail inválido"),
  phone: optionalText(20),
  password: z.string().min(6, "Senha deve ter ao menos 6 caracteres").max(72),
  role: roleSchema,
});

export const updateUserSchema = z
  .object({
    name: z.string().trim().min(2).max(120),
    document: optionalText(30),
    email: z.string().trim().toLowerCase().email("E-mail inválido"),
    phone: optionalText(20),
    password: z.string().min(6).max(72),
    role: roleSchema,
  })
  .partial()
  .refine((v) => Object.keys(v).length > 0, "Envie ao menos um campo");

export const updateUserStatusSchema = z.object({
  active: z.boolean(),
});

export const listUsersQuerySchema = paginationSchema.extend({
  search: z.string().trim().min(1).optional(), // nome ou documento
  role: roleSchema.optional(),
  active: booleanQuerySchema.optional(),
});

export type CreateUserDto = z.infer<typeof createUserSchema>;
export type UpdateUserDto = z.infer<typeof updateUserSchema>;
export type UpdateUserStatusDto = z.infer<typeof updateUserStatusSchema>;
export type ListUsersQuery = z.infer<typeof listUsersQuerySchema>;
