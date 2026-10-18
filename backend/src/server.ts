// backend/src/server.ts
// Ponto de entrada: `npm run dev` / `node dist/server.js`.
import { env } from "./config/env.js";
import { prisma } from "./config/prisma.js";
import { ensurePhotosDir } from "./config/photos.js";
import { app } from "./index.js";

// Cria a pasta de fotos se ela ainda não existir (nenhum erro se já existir).
ensurePhotosDir();

const server = app.listen(env.PORT, "0.0.0.0", (err?: Error) => {
  if (err) return; // no Express 5 o callback também recebe o erro; ele é tratado em server.on("error")
  console.log(`Servidor rodando na porta ${env.PORT}`);
  console.log(`Health check: http://localhost:${env.PORT}/health`);
  console.log(`Pasta de fotos: ${env.PHOTOS_DIR}`);
});

// Mantém nonces expirados por 24 horas para permitir auditoria de leituras atrasadas.
const qrNonceCleanup = setInterval(() => {
  const retentionCutoff = new Date(Date.now() - 24 * 60 * 60 * 1000);
  void prisma.qrnonce
    .deleteMany({ where: { expiresAt: { lt: retentionCutoff } } })
    .catch((error) => console.error("Falha ao limpar QR codes expirados:", error));
}, 60 * 60 * 1000);
qrNonceCleanup.unref();

server.on("error", (err: NodeJS.ErrnoException) => {
  if (err.code === "EADDRINUSE") {
    console.error(`Porta ${env.PORT} já está em uso. Feche o outro processo ou mude a PORT no .env.`);
  } else {
    console.error("Erro ao iniciar o servidor:", err);
  }
  process.exit(1);
});

// Encerramento limpo (Ctrl+C ou docker stop): fecha o servidor e a conexão com o banco.
async function shutdown(signal: string) {
  console.log(`\n${signal} recebido, encerrando...`);
  clearInterval(qrNonceCleanup);
  server.close(async () => {
    await prisma.$disconnect();
    process.exit(0);
  });
  // Se alguma conexão travar o encerramento, força a saída.
  setTimeout(() => process.exit(1), 10_000).unref();
}

process.on("SIGINT", () => void shutdown("SIGINT"));
process.on("SIGTERM", () => void shutdown("SIGTERM"));
