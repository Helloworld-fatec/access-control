import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";

// Em dev, /api é encaminhado ao backend: o front usa caminho relativo e não
// depende do IP (US-17). Em produção o Nginx do Compose faz o mesmo proxy.
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, ".", "");
  return {
    plugins: [react()],
    server: {
      host: true,
      port: 5173,
      proxy: { "/api": { target: env.BACKEND_URL || "http://localhost:3000", changeOrigin: true } },
    },
  };
});
