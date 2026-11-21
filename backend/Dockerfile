FROM node:22-slim

# O Prisma precisa do OpenSSL para migrar e consultar o PostgreSQL.
RUN apt-get update && apt-get install -y --no-install-recommends openssl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

# Gera o cliente do Prisma (não precisa de banco nesta etapa).
RUN npx prisma generate --config prisma7.config.ts

EXPOSE 3000

# Aplica as migrações e sobe a API.
CMD ["sh", "-c", "npx prisma migrate deploy --config prisma7.config.ts && npm start"]
