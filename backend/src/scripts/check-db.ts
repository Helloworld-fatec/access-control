// Diagnóstico da conexão com o banco (útil para o Neon).  Uso:  npm run db:check
import { env } from "../config/env.js";
import { prisma } from "../config/prisma.js";

const url = new URL(env.DATABASE_URL);
console.log(`Banco: ${url.hostname}:${url.port || 5432}${url.pathname}  (usuário ${decodeURIComponent(url.username)})`);
if (url.hostname.includes("-pooler")) {
  console.log("Aviso: host com '-pooler'. Para 'prisma migrate' use o host direto (sem '-pooler').");
}
if (url.hostname.includes("neon.tech") && url.searchParams.get("sslmode") !== "require") {
  console.log("Aviso: no Neon a URL deve terminar com ?sslmode=require");
}

const expected = ["users", "nfc_tags", "face_templates", "user_photos", "locations", "terminals", "authorizations", "access_logs", "qr_nonces"];

try {
  await prisma.$queryRaw`SELECT 1`;
  console.log("Conexão: OK");
  const rows = await prisma.$queryRaw<{ table_name: string }[]>`
    SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'`;
  const have = new Set(rows.map((r) => r.table_name));
  const missing = expected.filter((t) => !have.has(t));
  if (missing.length === 0) {
    console.log("Tabelas: OK (as 9 esperadas)");
    const admins = await prisma.user.count({ where: { role: "ADMIN", active: true } });
    console.log(`Administradores ativos: ${admins}${admins === 0 ? "  -> crie um: npm run admin:create -- email senha" : ""}`);
  } else {
    const legacy = rows.map((r) => r.table_name).filter((t) => /[A-Z]/.test(t));
    console.log(`Tabelas faltando: ${missing.join(", ")}`);
    if (legacy.length) console.log(`Há tabelas com maiúsculas (${legacy.join(", ")}): é o formato antigo. Veja docs/como-rodar.md.`);
    else console.log("Rode: npx prisma migrate deploy --config prisma7.config.ts  (ou docs/criar-tabelas.sql no pgAdmin)");
    process.exitCode = 1;
  }
} catch (e) {
  console.error("Falha ao conectar:", e instanceof Error ? e.message : e);
  process.exitCode = 1;
} finally {
  await prisma.$disconnect();
}
