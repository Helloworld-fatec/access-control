import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { AuthProvider } from "./features/auth/AuthContext";
import { ApiError, loadRuntimeConfig } from "./shared/api";
import { ToastProvider } from "./shared/toast";
import App from "./App";
import "./styles.css";

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 15_000,
      refetchOnWindowFocus: false,
      // Repete só falhas de rede; erro 4xx/5xx de negócio não adianta repetir.
      retry: (count, e) => e instanceof ApiError && e.status === 0 && count < 2,
    },
  },
});

async function start() {
  if (import.meta.env.VITE_MOCK === "true") (await import("./shared/mock")).installMock();
  await loadRuntimeConfig();
  createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <ToastProvider>
          <AuthProvider>
            <App />
          </AuthProvider>
        </ToastProvider>
      </BrowserRouter>
    </QueryClientProvider>
  </StrictMode>,
);
}

void start();
