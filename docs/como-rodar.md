# Como rodar o projeto (banco, backend e front)

O sistema tem três partes que precisam estar no ar ao mesmo tempo:

| Parte | O que é | Endereço |
| --- | --- | --- |
| Banco | PostgreSQL (local, Docker ou Neon) | porta 5432 |
| Backend | API Node/Express com Prisma | http://localhost:3000/api |
| Front | React (Vite) | http://localhost:5173 |

O front chama `/api` e o Vite encaminha para o backend, então o navegador só conversa com o front.

## Pré-requisitos

- **Node.js 22 ou mais novo** (já inclui o `npm`) e **Git**.
- Um **PostgreSQL**: no seu computador, no Docker ou no Neon (online).

## 1. Banco de dados

**Neon:** copie a URL de conexão do painel do Neon (Connection string) e use o host **direto** (sem `-pooler`), terminando em **`?sslmode=require`**. Apague parâmetros extras como `channel_binding=` vazio. O host com `-pooler` costuma falhar nas migrações.

Depois de configurar o `.env` do backend, confira tudo com:

```powershell
npm run db:check
```

Ele mostra se conectou, se as 9 tabelas existem (e se estão no formato antigo, com maiúsculas) e quantos administradores ativos há.

**Local:** crie um banco vazio, por exemplo `access_control`.

## 2. Backend

```powershell
cd backend
copy .env.example .env
```

Edite o `.env`:

```
DATABASE_URL="postgresql://USUARIO:SENHA@HOST:5432/BANCO?sslmode=require"
PORT=3000
JWT_SECRET="um-texto-secreto-com-no-minimo-32-caracteres"
JWT_EXPIRES_IN=1h
```

> **`JWT_SECRET` é obrigatório** e precisa ter 32 caracteres ou mais. Sem ele o backend não inicia e mostra "Variáveis de ambiente inválidas". Em banco local sem SSL, tire o `?sslmode=require`.

Depois:

```powershell
npm install
npx prisma generate --config prisma7.config.ts
npx prisma migrate deploy --config prisma7.config.ts
npm run admin:create -- admin@teste.com SuaSenha123 "Administrador"
npm run dev
```

Quando aparecer `Servidor rodando na porta 3000`, abra http://localhost:3000/api/health. Deve responder `{"status":"ok",...}`.

O `admin:create` cria o primeiro administrador no banco (ou redefine a senha dele, se o e-mail já existir).

## 3. Front

Em outro terminal:

```powershell
cd frontend
copy .env.example .env
npm install
npm run dev
```

Abra http://localhost:5173 e entre com o e-mail e a senha do administrador criado.

Sem backend, `npm run dev:mock` abre o front com dados de exemplo (entre com `admin@teste.com` e qualquer senha).

## Banco pelo pgAdmin (em vez do `migrate deploy`)

1. Conecte o pgAdmin ao banco (no Neon: **SSL mode = require**).
2. Abra o **Query Tool** no banco, carregue `docs/criar-tabelas.sql` e execute com **F5**. Devem aparecer 9 tabelas, todas em minúsculas (`users`, `nfc_tags`, `access_logs`...).
3. Avise o Prisma de que as migrações já foram aplicadas, **uma vez**, no `backend`:

```powershell
npx prisma migrate resolve --applied 20261010220339_init --config prisma7.config.ts
npx prisma migrate resolve --applied 20261018000000_rename_user_table_to_users --config prisma7.config.ts
npx prisma migrate resolve --applied 20261018010000_qr_nonce_consumed --config prisma7.config.ts
npx prisma migrate resolve --applied 20261018020000_lowercase_model_tables --config prisma7.config.ts
```

> **Se você já rodou um `criar-tabelas.sql` antigo** e o banco tem tabelas com maiúsculas (`"User"`, `"NfcTag"`...), ele está no formato errado. Se o banco não tem dados que você queira guardar, apague tudo e recomece: `DROP SCHEMA public CASCADE; CREATE SCHEMA public;` e depois execute o `criar-tabelas.sql` novo. **Isso apaga todos os dados.**

## Docker (tudo de uma vez)

Na raiz do projeto:

```powershell
copy .env.docker.example .env
notepad .env
```

Preencha as duas linhas **obrigatórias** do `.env`. Não existe senha nem segredo padrão: o Compose se recusa a subir enquanto elas estiverem vazias.

| Variável | O que colocar |
| --- | --- |
| `POSTGRES_PASSWORD` | Uma senha só com letras e números (caracteres como `@`, `#`, `/` e `:` quebram a URL do banco) |
| `JWT_SECRET` | Texto com 32 caracteres ou mais. Gere com `node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"` |

O `.env` não vai para o Git (está no `.gitignore`) e nenhum segredo está escrito no `docker-compose.yml`. Depois:

```powershell
docker compose up --build -d
docker compose ps
docker compose exec backend npm run admin:create -- admin@teste.com SuaSenha123 "Administrador"
```

O `docker compose ps` deve mostrar `db`, `backend` e `frontend` como **healthy**. O backend só fica saudável depois que as migrações rodaram e a API respondeu, e o front só sobe depois do backend. O front fica em http://localhost:8080 (o Nginx encaminha `/api` ao backend) e a API em http://localhost:3000/api, que é o endereço que os aplicativos e o ESP32 usam. O banco não abre porta no computador: só os outros serviços o alcançam.

### Quando algo falha

```powershell
docker compose ps -a                          # qual serviço caiu ou está "unhealthy"
docker compose logs --tail=100 backend        # troque por db ou frontend
docker compose down                           # para tudo (mantém o banco)
docker compose down -v                        # para tudo e APAGA o banco e as fotos
```

| Mensagem ou sintoma | Causa provável |
| --- | --- |
| `Defina POSTGRES_PASSWORD no arquivo .env` ou `Defina JWT_SECRET ...` | O `.env` não existe na raiz ou a linha está vazia |
| Backend em loop de reinício, log com `password authentication failed` | Você trocou o `POSTGRES_PASSWORD` depois de o banco já existir. Rode `docker compose down -v` (apaga os dados) e suba de novo |
| Backend `unhealthy` e log com `Variáveis de ambiente inválidas` | `JWT_SECRET` com menos de 32 caracteres |
| Front abre, mas o login mostra "Não foi possível conectar" | Backend ainda não está `healthy`; veja `docker compose ps` |
| `port is already allocated` | Outra coisa usa a porta 8080 ou 3000; mude `FRONTEND_PORT` ou `BACKEND_PORT` no `.env` |

> **Estado da validação:** o roteiro completo (subir, esperar ficar saudável, criar admin, fazer login e consultar o painel) está no GitHub Actions (`.github/workflows/ci.yml`, job `docker compose`), mas **ainda não rodou**: quem abrir o primeiro Pull Request deve conferir se o job passou. Onde este documento foi escrito não havia acesso ao Docker Hub, então as imagens não foram construídas ali. A sintaxe do Compose foi validada com `docker compose config` e o Nginx foi testado separadamente (rotas do React, proxy da API e `config.json`).

## Problemas comuns

| Sintoma | Causa provável |
| --- | --- |
| Backend não sobe: "Variáveis de ambiente inválidas" | Falta `JWT_SECRET` (mínimo 32 caracteres) ou `DATABASE_URL` |
| `Missing script: "dev"` | Backend desatualizado; use a versão com os scripts `dev` e `start` |
| Front: "Não foi possível conectar ao servidor" | Backend desligado ou `BACKEND_URL` errado no `.env` do front |
| Login: "Erro interno do servidor" | Veja o terminal do backend: costuma ser banco sem tabelas ou senha do banco errada |
| Tags, foto, rosto ou histórico dão erro 500 | Backend sem a correção dos nomes dos modelos no `schema.prisma` |
| `prisma migrate` falha no Neon | Use o host sem `-pooler` |
| Sessão cai depois de 1 hora | Esperado: o token expira e ainda não existe renovação |
| Painel: "Este indicador ainda não existe no backend" | Backend desatualizado: faltam as rotas `/dashboard/*` |

## Painel

Os indicadores (`/dashboard/summary`, `/dashboard/accesses-by-hour`) e a situação dos terminais (`/terminals/status`) vêm do backend e exigem o token de administrador. Só o **estado da trava** não existe no backend.

## Pendências conhecidas do backend (decisão do grupo)

- **Rotas sem JWT.** `users`, `locations` e `access-logs` estão abertas de propósito ("temporariamente", no `routes/index.ts`). Antes da entrega, ative o `routes.use(authenticate)` e libere só o que os apps e terminais precisam. Com isso ativo, o primeiro administrador só pode ser criado por `npm run admin:create`.
- **Renovação de sessão:** não existe `/auth/refresh`; o token dura 1 hora.
- **Estado da trava** do terminal: o backend não guarda essa informação.
- **Terminal online:** o backend nunca marca `online` sozinho; o painel considera online quem falou com a API nos últimos 2 minutos.
- **Tag NFC (US-07):** o backlog novo pede "Gravar tag" pelo terminal, com situação da tag. O backend ainda vincula por UID e não tem `GET /users/{id}/tags`.
