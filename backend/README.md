# backend

API REST do **access-control**: concentra a autenticação, a decisão de acesso (QR Code, NFC e rosto), o cadastro de usuários, locais, terminais e autorizações, e o registro de toda tentativa de acesso. Os aplicativos e o dispositivo só coletam a credencial; quem decide é o backend.

Responsáveis: Bruno e Pedro. Documentação das rotas em [`docs/api.md`](../docs/api.md).

## Tecnologias

Node.js 24, Express 5, TypeScript, Prisma 7 com PostgreSQL, Zod (validação), bcrypt (senhas), JSON Web Token (login), Multer (upload de foto) e Vitest com Supertest (testes).

## Variáveis de ambiente

Copie `.env.example` para `.env`. O arquivo de exemplo traz só `DATABASE_URL`, `PORT` e `JWT_SECRET`; as demais têm valor padrão.

| Variável | Obrigatória | Padrão | Descrição |
|---|---|---|---|
| `DATABASE_URL` | Sim | | Conexão com o PostgreSQL |
| `JWT_SECRET` | Sim | | Segredo do JWT, com **pelo menos 32 caracteres** |
| `PORT` | Não | `3000` | Porta da API |
| `JWT_EXPIRES_IN` | Não | `1h` | Validade do token de login |
| `BCRYPT_ROUNDS` | Não | `10` | Custo do hash de senha (4 a 15) |
| `PHOTOS_DIR` | Não | `photos` | Pasta das fotos, criada automaticamente |
| `MAX_PHOTO_BYTES` | Não | `102400` | Tamanho máximo da foto (100 KB) |

Se alguma variável obrigatória faltar, o servidor não sobe e lista o que está errado.

## Como rodar

Pré-requisitos: Node.js 24 e um PostgreSQL. Para subir só o banco com Docker, use o arquivo da raiz:

```bash
docker compose -f docker-compose.test.yml up -d
```

Ele cria o PostgreSQL na porta `5433` com usuário `postgres`, senha `changeme` e banco `access_control_test`. O `DATABASE_URL` correspondente é:

```
postgresql://postgres:changeme@localhost:5433/access_control_test?schema=public
```

Depois, na pasta `backend`:

```bash
cp .env.example .env     # edite DATABASE_URL e JWT_SECRET
npm install
npx prisma generate
npx prisma migrate deploy
npx tsx src/server.ts
```

A API sobe em `http://localhost:3000`. Para conferir:

```bash
curl http://localhost:3000/api/health
```

> O `package.json` ainda não tem os scripts `dev`, `build` e `start` (só `test` e `test:watch`), por isso o servidor sobe com `npx tsx src/server.ts`. O Prisma encontra a configuração `prisma7.config.ts` sozinho.

### Primeiro administrador

O projeto ainda não tem seed. Como a rota de usuários não exige login, crie o primeiro administrador assim:

```bash
curl -X POST http://localhost:3000/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Administrador","email":"admin@teste.com","password":"admin123","role":"ADMIN"}'
```

Depois faça o login em `POST /api/login` e use o `accessToken` nas rotas protegidas.

## Testes

```bash
npm test
```

Executa `prisma generate` e o Vitest. Hoje são 2 arquivos e 4 testes (rota de saúde e serviço de acesso), que não precisam de banco.

## Estrutura

```
backend/
├── prisma/            schema.prisma e migrations
├── src/
│   ├── config/        variáveis de ambiente, Prisma e pasta de fotos
│   ├── controllers/   as funções de cada recurso
│   ├── middlewares/   JWT, administrador, terminal, upload, limite de requisições e erros
│   ├── models/        modelos de resposta e DTOs com Zod
│   ├── routes/        montagem das rotas sob o prefixo /api
│   ├── services/      abertura da porta (hoje simulada)
│   ├── types/         perfis, métodos, resultados e motivos de negação
│   ├── index.ts       monta o app Express
│   └── server.ts      sobe o servidor
├── prisma7.config.ts  configuração do Prisma 7
└── vitest.config.ts
```

## Modelo de dados

Tabelas: `users`, `nfc_tags`, `face_templates`, `user_photos`, `locations`, `terminals`, `authorizations`, `access_logs` e `qr_nonces`. Senhas ficam em hash (bcrypt), o QR é guardado como SHA-256 e a chave do terminal como hash. O rosto é guardado como vetor (embedding), nunca como imagem. O diagrama está em [`docs/arquitetura.md`](../docs/arquitetura.md).

## O que ainda não está implementado

- Publicação MQTT para o ESP32: hoje só um log `[MQTT SIMULADO]`.
- Validação da distância entre o celular e o terminal.
- Login obrigatório nas rotas de usuários, locais e histórico.

Detalhes em "Limitações conhecidas" de [`docs/api.md`](../docs/api.md).
