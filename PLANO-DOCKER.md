# Plano de Dockerização do access-control

Este documento descreve a implementação do ambiente local com Docker Compose para o painel web, a API e o PostgreSQL. O navegador acessará o frontend em `http://localhost:8888`; a API ficará disponível em `http://localhost:3333` e também será encaminhada pelo Nginx em `/api`.

## 1. O que foi identificado no projeto

- `frontend/` é React + TypeScript + Vite. `npm run build` gera os arquivos estáticos em `frontend/dist`. A aplicação chama a API pelo caminho relativo `/api`; o `frontend/public/config.json` também define `apiUrl: "/api"`.
- `backend/` é Express 5 + TypeScript e inicia pelo arquivo `src/server.ts`. O servidor escuta `0.0.0.0`, lê `PORT` (padrão `3000`) e oferece `GET /api/health`.
- O backend usa Prisma 7 com `@prisma/adapter-pg`. A URL do banco é configurada em `DATABASE_URL`; o arquivo `prisma7.config.ts` informa o schema e a pasta `prisma/migrations`.
- Existem quatro migrações versionadas em `backend/prisma/migrations`. O container deve executar `prisma migrate deploy` antes de iniciar a API.
- A API exige `JWT_SECRET` com pelo menos 32 caracteres. Também aceita `PHOTOS_DIR`, `BCRYPT_ROUNDS`, `JWT_EXPIRES_IN` e `MAX_PHOTO_BYTES`.
- O backend salva fotos em disco. O diretório precisa ser montado em volume persistente para que uploads sobrevivam à recriação do container.
- O `backend/package.json` ainda não possui scripts de `build`, `start` ou `dev`; seus scripts declarados hoje são de testes. O Dockerfile/plano deve definir explicitamente como gerar o Prisma Client e iniciar `src/server.ts`, em vez de depender de scripts inexistentes.
- `docker-compose.test.yml` é usado para um PostgreSQL de testes na porta `5433`; o Compose principal deve usar outro nome de serviço e volume para não confundir ou reutilizar o banco de testes.
- A documentação do frontend já prevê Nginx como proxy de `/api` em produção. O Vite proxy é apenas para desenvolvimento.

## 2. Arquivos a criar

Na raiz:

```text
docker-compose.yml
```

No frontend:

```text
frontend/Dockerfile
frontend/nginx.conf
frontend/.dockerignore
```

No backend:

```text
backend/Dockerfile
backend/.dockerignore
```

Opcionalmente, adicionar variáveis sem segredos ao `backend/.env.example` ou criar um `.env.docker.example` na raiz como referência. Não versionar `.env` real.

## 3. Configurar o backend para execução em container

1. Definir scripts claros no `backend/package.json`: `start` executa `tsx src/server.ts`, `db:deploy` executa `prisma migrate deploy --config prisma7.config.ts` e `db:generate` gera o cliente Prisma com a mesma configuração.
2. Usar `tsx` para iniciar o TypeScript no container, pois o projeto ainda não configura emissão JavaScript em `dist/`.
3. Rodar `prisma generate` durante o build, usando `prisma7.config.ts`; o cliente gerado em `src/generated/prisma` deve estar disponível na imagem final.
4. No startup, aguardar o banco ficar saudável via dependência do Compose, aplicar `prisma migrate deploy` e só então iniciar o servidor. Se a migração falhar, o container deve encerrar com erro.
5. Configurar `PORT=3333` no serviço backend. O processo já escuta em `0.0.0.0`, portanto ficará acessível aos outros containers.
6. Configurar `PHOTOS_DIR` para `/app/photos` e preparar esse diretório na imagem com permissões adequadas ao usuário sem privilégios.

### Etapas do `backend/Dockerfile`

1. Usar uma imagem Node LTS compatível com a versão instalada de Prisma e as dependências nativas de `bcrypt`.
2. Copiar primeiro `package.json` e `package-lock.json`; instalar com `npm ci`.
3. Copiar schema, migrações, `prisma7.config.ts`, configuração TypeScript e código-fonte.
4. Rodar `npx prisma generate` e, se adotada compilação, o build TypeScript.
5. Manter as dependências de execução necessárias a `tsx` e ao CLI Prisma, pois o container aplica migrações no startup; executar como usuário não root.
6. Definir comando de inicialização com migração seguida do servidor, preservando sinais de encerramento para o tratamento SIGTERM já implementado em `server.ts`.

## 4. Criar o Dockerfile do frontend

Usar build em múltiplos estágios:

1. Estágio Node: copiar `frontend/package*.json`, instalar dependências com `npm ci`, copiar o restante do frontend e executar `npm run build`.
2. Estágio final: usar Nginx Alpine e copiar `frontend/dist` para o diretório público do Nginx.
3. Copiar `frontend/nginx.conf` para a configuração do Nginx.
4. Configurar o container para escutar na porta interna `80`; o Compose publicará `8888:80`.
5. Configurar fallback de rotas do React Router para `index.html`, para que recarregar uma rota do painel não resulte em 404.

## 5. Configurar Nginx como proxy reverso

No `frontend/nginx.conf`:

1. Servir o build do frontend na raiz (`/`) e aplicar fallback de SPA.
2. Criar uma localização `/api/` que encaminhe as requisições para `http://backend:3333`, preservando o prefixo `/api` e os métodos, cabeçalhos e corpo da requisição.
3. Configurar timeouts e encaminhar cabeçalhos `Host`, `X-Real-IP` e `X-Forwarded-For`.
4. Opcionalmente, encaminhar `/api` sem barra final da mesma forma que `/api/`, evitando comportamento inconsistente nesse caminho.
5. Não usar `localhost` como destino do proxy: dentro do container, isso aponta para o próprio Nginx. O destino deve ser o nome DNS do serviço Compose `backend`.

O caminho relativo já usado pelo frontend (`/api`) permite que o navegador faça chamadas à mesma origem `http://localhost:8888`; assim, o Nginx encaminha a API sem exigir URL de backend embutida no build ou configuração adicional de CORS.

## 6. Definir `docker-compose.yml`

Criar três serviços na mesma rede padrão do Compose:

### `postgres`

- Imagem oficial `postgres:17-alpine`, alinhada ao Compose de testes existente.
- Configurar `POSTGRES_DB`, `POSTGRES_USER` e `POSTGRES_PASSWORD` via variáveis do `.env` da raiz, com valores locais documentados para desenvolvimento.
- Publicar `5432:5432` para acesso local pelo host. O Compose de testes continua usando `5433` e volume separado.
- Usar volume nomeado próprio, por exemplo `access_control_pgdata`, em `/var/lib/postgresql/data`.
- Definir healthcheck com `pg_isready`, usando as mesmas credenciais configuradas.

### `backend`

- Construir usando `backend/Dockerfile`.
- Definir `PORT=3333`, `JWT_SECRET`, `DATABASE_URL`, `PHOTOS_DIR=/app/photos` e demais configurações necessárias.
- A `DATABASE_URL` dentro do Compose deve usar o hostname `postgres` e a porta interna `5432`, por exemplo `postgresql://<usuario>:<senha>@postgres:5432/<banco>?schema=public`.
- Aguardar `postgres` ficar `healthy` antes de iniciar. O comando de startup aplica as migrações e depois inicia a API.
- Publicar `3333:3333` para permitir acesso direto à API durante desenvolvimento e depuração.
- Montar volume nomeado para `/app/photos`.
- Adicionar healthcheck HTTP para `http://localhost:3333/api/health`, se a imagem tiver uma ferramenta adequada para a checagem. Se não tiver, usar uma checagem compatível com Node já disponível na imagem.

### `frontend`

- Construir usando `frontend/Dockerfile`.
- Publicar `8888:80`.
- Depender do backend para ordem de inicialização, sem embutir URL `localhost` no build.
- O proxy Nginx conversa com `backend:3333` pela rede Compose.

### Dados e segredos

- Criar `.env.example` na raiz com nomes e valores de desenvolvimento claramente identificados para `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` e `JWT_SECRET`.
- Adicionar `.env` da raiz ao `.gitignore`; manter credenciais reais fora do repositório.
- Para uso compartilhado ou produção, trocar valores de exemplo por segredos fortes fornecidos pelo ambiente de deploy.
- Nomear explicitamente os volumes do banco e das fotos para evitar colisão com `docker-compose.test.yml`.

## 7. Adicionar `.dockerignore`

Em `backend/.dockerignore` e `frontend/.dockerignore`, ignorar pelo menos:

```text
node_modules
dist
.env
.env.*
!.env.example
coverage
.git
```

No backend, também ignorar fotos locais e saídas geradas que não sejam necessárias como fonte. Confirmar que os arquivos de migração e configurações Prisma não sejam excluídos.

## 8. Fluxo de execução para documentar

Depois de implementar os arquivos, documentar na raiz:

```bash
cp .env.example .env
# preencher JWT_SECRET com pelo menos 32 caracteres e definir credenciais locais
docker compose up --build
```

Endereços esperados:

- Painel: `http://localhost:8888`
- API via proxy: `http://localhost:8888/api/health`
- API direta: `http://localhost:3333/api/health`
- PostgreSQL no host, se publicado: `localhost:5432`

Comandos operacionais úteis:

```bash
docker compose ps
docker compose logs -f backend
docker compose down
```

`docker compose down` preserva volumes. Para apagar também os dados persistidos, usar `docker compose down -v` conscientemente; isso remove o banco e as fotos mantidas nos volumes.

## 9. Critérios de conclusão

- `docker compose up --build` inicia PostgreSQL, executa migrações e mantém os três serviços ativos.
- `http://localhost:8888` carrega o frontend e as rotas internas do painel continuam funcionando após recarregar a página.
- `http://localhost:8888/api/health` retorna a resposta de saúde da API via Nginx.
- `http://localhost:3333/api/health` retorna a mesma resposta diretamente do backend.
- Reiniciar os containers preserva registros no PostgreSQL e fotos enviadas.
- O backend encerra de forma limpa quando o Compose o interrompe.
- `.env`, dependências locais e dados persistentes não são copiados para as imagens nem versionados.

## 10. Pontos a confirmar durante a implementação

- Adotar build TypeScript para runtime ou `tsx` no container inicial.
- Decidir se a porta do PostgreSQL ficará publicada no host.
- Definir valores e política de fornecimento de segredos para desenvolvimento, sem commitar credenciais reais.
- Confirmar se a instalação do Prisma Client e do `bcrypt` funciona na imagem Node escolhida e se o runtime contém tudo que o comando de migração precisa.
