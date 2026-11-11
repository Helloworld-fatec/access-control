import { loadEnv } from "vite";
import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";

// Em dev, /api é encaminhado ao backend: o front usa caminho relativo e não
// depende do IP (US-17). Em produção o Nginx do Compose faz o mesmo proxy.
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, ".", "");
  return {
    plugins: [react()],
    test: {
      environment: "jsdom",
      setupFiles: ["./src/test/setup.ts"],
      css: false,
      // A API de teste é absoluta: o fetch do Node não aceita caminho relativo.
      env: { VITE_API_URL: "http://localhost/api" },
    },
    server: {
      host: true,
      port: 5173,
      proxy: { "/api": { target: env.BACKEND_URL || "http://localhost:3000", changeOrigin: true } },
    },
  };
});
