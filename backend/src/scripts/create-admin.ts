import bcrypt from "bcrypt";
import { prisma } from "../config/prisma.js";
import { env } from "../config/env.js";
import { createUserSchema } from "../models/dtos/user.dto.js";

async function createAdmin() {
  const account = createUserSchema.safeParse({
    name: "Administrador",
    email: process.env.ADMIN_EMAIL,
    password: process.env.ADMIN_PASSWORD,
    role: "ADMIN",
  });
  if (!account.success || Buffer.byteLength(account.data.password, "utf8") > 72) {
    throw new Error("Informe ADMIN_EMAIL válido e ADMIN_PASSWORD de 6 a 72 bytes.");
  }

  const { email, name, password, role } = account.data;
  const existing = await prisma.user.findUnique({
    where: { email },
    select: { role: true, active: true },
  }).catch(() => {
    throw new Error("Não foi possível consultar o administrador. Confira a conexão com o banco.");
  });
  if (existing) {
    if (existing.role !== role || !existing.active) {
      throw new Error("O e-mail já está vinculado a uma conta que não é uma administradora ativa.");
    }
    console.log("Administrador ativo já cadastrado. A senha existente foi preservada.");
    return;
  }

  try {
    await prisma.user.create({
      data: { email, name, role, passwordHash: await bcrypt.hash(password, env.BCRYPT_ROUNDS) },
      select: { id: true },
    });
  } catch {
    throw new Error("Não foi possível criar o administrador. Confira o banco e se o e-mail já existe.");
  }
  console.log("Administrador criado.");
}

try {
  await createAdmin();
} catch (error) {
  console.error(error instanceof Error ? error.message : "Falha ao criar administrador.");
  process.exitCode = 1;
} finally {
  await prisma.$disconnect();
}
