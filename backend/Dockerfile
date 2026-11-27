FROM node:22-alpine

WORKDIR /app

# Prisma's PostgreSQL engine and bcrypt need the platform runtime libraries.
RUN apk add --no-cache openssl \
    && addgroup -S app \
    && adduser -S -G app app

COPY package.json package-lock.json ./
RUN npm ci --include=dev

COPY prisma ./prisma
COPY prisma7.config.ts tsconfig.json ./
COPY src ./src
COPY pokemon-data ./pokemon-data

RUN npm run db:generate \
    && mkdir -p /app/uploads \
    && chown -R app:app /app

ENV NODE_ENV=production \
    PORT=3333 \
    PHOTOS_DIR=/app/uploads

USER app

EXPOSE 3333

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:3333/api/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

# Apply versioned migrations before serving requests. exec forwards container signals.
CMD ["sh", "-c", "npm run db:deploy && exec npm start"]
