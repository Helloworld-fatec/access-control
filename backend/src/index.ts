// backend/src/index.ts

// Monta e exporta o app Express. Quem sobe o servidor é o server.ts.

import express from "express";
import cors from "cors";
import { z } from "zod";

import { routes } from "./routes/index.js";
import {
  errorHandler,
  notFoundHandler,
} from "./middlewares/error.middleware.js";

// Mensagens padrão de validação do Zod em português.
z.config(z.locales.pt());

export const app = express();

// CORS permissivo para o projeto acadêmico.
app.use(cors());

app.use(express.json());

// Todas as rotas recebem o prefixo /api.
app.use("/api", routes);

// Sempre por último: rota inexistente e tratamento central de erros.
app.use(notFoundHandler);
app.use(errorHandler);

export default app;
