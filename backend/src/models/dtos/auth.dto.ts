import { z } from "zod";

export const loginSchema = z.object({
  email: z.string().trim().toLowerCase().email("E-mail inválido"),
  password: z.string().min(1, "Senha obrigatória").max(72),
});

export type LoginDto = z.infer<typeof loginSchema>;
