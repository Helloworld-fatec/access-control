// Cria (ou atualiza) um administrador direto no banco. Útil no primeiro acesso e
// quando as rotas passarem a exigir JWT (aí não dá mais para criar o 1º admin pela API).
//
// Uso:  npm run admin:create -- admin@exemplo.com SenhaForte123 "Nome do Admin"
import bcrypt from "bcrypt";
import { env } from "../config/env.js";
import { prisma } from "../config/prisma.js";

const [email, password, name = "Administrador"] = process.argv.slice(2);

if (!email || !password) {
  console.error('Uso: npm run admin:create -- <email> <senha> ["Nome"]');
  process.exit(1);
}
if (password.length < 6) {
  console.error("A senha deve ter ao menos 6 caracteres.");
  process.exit(1);
}

const passwordHash = await bcrypt.hash(password, env.BCRYPT_ROUNDS);
const normalized = email.trim().toLowerCase();

const user = await prisma.user.upsert({
  where: { email: normalized },
  create: { name, email: normalized, passwordHash, role: "ADMIN", active: true },
  update: { passwordHash, role: "ADMIN", active: true },
  select: { id: true, email: true, role: true },
});

console.log(`Administrador pronto: ${user.email} (id ${user.id})`);
await prisma.$disconnect();
