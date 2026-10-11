// backend/src/index.ts
// Monta e exporta o app Express. Quem sobe o servidor é o server.ts.
import express from "express";
import cors from "cors";
import { z } from "zod";
import { routes } from "./routes/index.js";
import { errorHandler, notFoundHandler } from "./middlewares/error.middleware.js";

// Mensagens padrão de validação do Zod em português (as mensagens próprias dos DTOs não mudam).
z.config(z.locales.pt());

export const app = express();

// CORS totalmente permissivo (qualquer origem, método e cabeçalho).
// Aceitável no projeto acadêmico em LAN; restringir antes de qualquer uso real.
app.use(cors());

app.use(express.json());

app.use(routes);

// Sempre por último: rota inexistente e tratamento central de erros.
app.use(notFoundHandler);
app.use(errorHandler);

export default app;