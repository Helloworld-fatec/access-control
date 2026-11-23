# frontend

Interface web de administração do **access-control** (React, TypeScript e Vite).
Cobre o Épico 6 do `scrum/BACKLOG.md`. As especificações visuais (cores, fonte, layout, componentes, telas e
acessibilidade) estão em [`docs/frontend.md`](../docs/frontend.md). O visual atual é inspirado em menus de jogo
(faixa vermelha, itens em pílula, rodapé de atalhos de teclado). A primeira versão usava a paleta da Fatec;
como voltar a ela está na seção 11 do documento.

## Como rodar

Com o backend e o banco no ar (veja `docs/como-rodar.md` na raiz do projeto):

```bash
cp .env.example .env     # ajuste BACKEND_URL se o backend não estiver em localhost:3000
npm install
npm run dev              # http://localhost:5173
```

Entre com um administrador. Para criar um, no `backend/`:
`npm run admin:create -- email senha "Nome"`.

O Vite encaminha `/api` para o backend, então o front usa caminho relativo e não depende de IP.

### Sem backend (modo demonstração)

```bash
npm run dev:mock
```

A API é simulada no navegador, com dados de exemplo. Entre com **admin@teste.com** e qualquer senha.
Os dados voltam ao início ao recarregar a página. O código está em `src/shared/mock.ts` e não entra na build normal.

O modo demonstração é ligado pelo arquivo `.env.mock` (conteúdo: `VITE_MOCK=true`). Se ele faltar, o
`dev:mock` chama a API de verdade e o Vite devolve erro 500 por não achar o backend.

### Com Docker

O `docker-compose.yml`, na raiz do projeto, sobe banco, backend e front (Nginx). O front usa `frontend/Dockerfile` e
`frontend/deploy/nginx.conf`. Os comandos estão em `docs/como-rodar.md`.

### Qualidade

```bash
npm run typecheck   # tipos
npm run lint        # ESLint (inclui a proibição de dangerouslySetInnerHTML)
npm test            # Vitest + Testing Library + MSW (58 testes)
npm run check       # os três, em sequência
```

## Integração com o backend real

Validado contra o backend e um PostgreSQL de verdade: login (`POST /api/login`), usuários, tags, locais,
terminais, autorizações, histórico com filtros, exportação em CSV, painel e acessos gerados pelo terminal (`/access/nfc`).
Veja `docs/como-rodar.md` (na raiz do projeto) para subir tudo.

- Só os 401 com código `UNAUTHORIZED` ou `INVALID_TOKEN` encerram a sessão. O `401 TERMINAL_UNAUTHORIZED`
  de `GET /terminals/{id}/status` (que exige a chave do terminal) só aparece no cartão do terminal.
- O backend devolve texto vazio em alguns campos opcionais (ex.: descrição do local); o front mostra "—".

## Backend

O front usa os endpoints do backend desta branch:

- **Login:** `POST /api/login` → `{ accessToken, tokenType, expiresIn, user }`. O token vai em `Authorization: Bearer`.
  Só administradores entram. O token dura `JWT_EXPIRES_IN` (padrão 1h) e **não há renovação** (`/auth/refresh` não existe):
  ao expirar, o front volta ao login com a mensagem "Sua sessão expirou. Entre novamente."
- **Autorizações:** o administrador que cria ou cancela vem do token; o front não envia `createdById` nem `canceledById`.
- Se o backend for antigo e responder 404 em `POST /login`, o front entra em *modo de desenvolvimento*:
  acha o administrador pelo e-mail e **não confere a senha** (há um aviso na tela). Desligue com `VITE_DEV_AUTH=false`.
- No `.env` do backend é preciso `JWT_SECRET` com **pelo menos 32 caracteres**.
- **Rotas ainda sem JWT:** `users` (incluindo tags, rosto e foto), `locations` e a listagem do histórico (`GET /access-logs`)
  continuam abertas, como combinado, para o JWT ser ligado depois. Já exigem token: `authorizations`, o CRUD de
  `terminals`, o painel (`/dashboard/*`, `/terminals/status`) e a exportação (`/access-logs/export`). O front já envia o token
  e trata o 401, então ligar o JWT nas rotas abertas não exige alteração aqui. Antes de ligar, confira se os aplicativos
  mobile e o terminal usam alguma dessas rotas sem token, porque eles passariam a receber 401.

## Painel (dashboard)

Tela inicial após o login (`/painel`), com resumo do dia, gráfico de acessos por hora (Recharts, com tabela equivalente
para leitores de tela), acessos por método, motivos de negação, autorizações, status dos terminais e últimos acessos.
Os terminais e os últimos acessos atualizam sozinhos a cada 5 segundos, com opção de pausar.

O painel usa endpoints reais do backend (todos exigem o token de administrador):

| Endpoint | Resposta |
| --- | --- |
| `GET /dashboard/summary?date=AAAA-MM-DD` | `{ date, granted, denied, denialRate (0 a 1), byMethod: {QR, NFC, FACE}, authorizations: {active, expiringSoon, canceled}, topDenialReasons: [{reason, count}] }` |
| `GET /dashboard/accesses-by-hour?date=AAAA-MM-DD` | `[{ hour (0 a 23), granted, denied }]`, 24 itens, hora em America/Sao_Paulo |
| `GET /terminals/status` | `{ data: [{ id, name, online, presenceActive, lastPresenceAt, lastSeenAt }] }` |
| `GET /access-logs?pageSize=10` | últimos acessos |

Regras: o dia vai de 00:00 a 24:00 em São Paulo; "expirando" são as autorizações ativas que vencem em até 7 dias;
um terminal conta como online se `online` é verdadeiro **ou** falou com a API nos últimos 2 minutos.
"Autorizações ativas" conta só as que ainda não venceram: uma autorização com data de término no passado aparece como
"Vencida" e não entra em nenhum dos três cartões.
O estado da trava não existe no backend: o cartão só o mostra no modo demonstração (`npm run dev:mock`).

## Exportação do histórico (CSV)

Na tela **Histórico de acessos**, o botão **Exportar CSV** pede confirmação (o arquivo contém dados pessoais) e baixa o
arquivo gerado pelo servidor, com os mesmos filtros da tela e **sem paginação**.

| Endpoint | Resposta |
| --- | --- |
| `GET /access-logs/export` (mesmos filtros da listagem) | CSV, só para administrador |

- **Formato:** separador `;`, quebra de linha CRLF e UTF-8 com BOM (o Excel em português abre direto). Colunas:
  Data e hora (São Paulo), Pessoa, Terminal, Método, Resultado e Motivo. O UID da tag não vai no arquivo.
- **Limite:** até 50.000 registros por arquivo. Acima disso o servidor responde `413 EXPORT_TOO_LARGE` e o aviso pede
  para reduzir o período ou usar mais filtros.
- **Segurança:** nomes que começam com `=`, `+`, `-` ou `@` recebem um apóstrofo na frente, para o Excel não executá-los
  como fórmula. O servidor lê o histórico em lotes, então a memória não cresce com o tamanho do arquivo.
- O modo demonstração também exporta (arquivo de exemplo).

## Configuração do endereço da API (sem rebuild)

O front chama `/api` (caminho relativo). Em desenvolvimento o proxy do Vite faz o encaminhamento; em produção,
o proxy reverso (Nginx do Compose) faz o mesmo, o que também evita problemas de CORS.

Para apontar para outro endereço **sem refazer a build**, edite `config.json`, servido junto com o front
(em desenvolvimento: `public/config.json`):

```json
{ "apiUrl": "http://192.168.0.10:3000/api" }
```

**Esquema:** front e backend devem usar o mesmo esquema (os dois em HTTP ou os dois em HTTPS). Páginas em HTTPS
não conseguem chamar uma API em HTTP (bloqueio de conteúdo misto).

## Segurança e privacidade (LGPD)

- **Token:** fica só em memória; nunca em `localStorage` ou `sessionStorage`. Recarregar a página pede novo login.
- **XSS:** nenhum `dangerouslySetInnerHTML` (o ESLint bloqueia). Nome, descrição e demais campos livres são exibidos como texto.
- **Dados pessoais exibidos:** nome, perfil, e-mail, telefone, foto e horários de entrada, **somente a administradores**,
  com a finalidade de gestão de acessos, segurança do local e auditoria (RF06, RF17).
  O documento aparece parcialmente oculto (só os 3 últimos caracteres). Embeddings faciais nunca são exibidos.
- **Exportação:** o CSV leva nomes e horários para fora do sistema. Por isso exige administrador, mostra um aviso antes
  de baixar e não inclui o documento nem o UID das tags.
- **Foto:** buscada por requisição autenticada e exibida via `URL.createObjectURL` (a tag `<img>` não envia o token).
- **HTTP na LAN de demonstração:** funciona, mas o tráfego não é cifrado (limitação aceita para a demonstração).
  Em HTTP fora de `localhost`, o navegador desativa o botão **Copiar chave** do terminal; a chave continua visível
  para copiar à mão.

## Tag NFC

A tag é vinculada por UID digitado ou por leitor USB que emula teclado, que é o que o backend aceita hoje
(`POST /users/{id}/tags` com o UID). A **Web NFC API não é usada**: ela só funciona no Chrome para Android e exige HTTPS.

> O backlog da US-07 foi atualizado: agora pede "Gravar tag" pelo terminal, com a situação da tag
> (pendente, ativa, falha, revogada) e sem leitor USB. Isso depende de endpoints que o backend ainda não tem
> (`GET /users/{id}/tags` e a gravação pelo terminal). Ao implementá-los, trocar o formulário de UID por esse fluxo.

## Situação das user stories

Veja `criterios-de-aceite-frontend.md` (na raiz da entrega) para cada critério.

**Concluídas:** US-01 a US-06 e US-09 a US-19, incluindo o painel (US-15, US-16, integrado ao backend) e a
exportação do histórico (US-14).

**Ainda não existem:**

- Gravação de tag pelo terminal (US-07), por depender de endpoints novos no backend (veja a seção Tag NFC).
- Foto por upload ou webcam (US-08).
- Teste ponta a ponta com Playwright e execução automática no CI (US-20); os testes unitários e de componentes já existem.
- Estado da trava no painel, que o backend não tem.
- JWT em `users`, `locations` e na listagem do histórico, que ainda estão abertas (decisão do grupo, veja a seção Backend).
- Revisão de acessibilidade com leitor de tela (US-18): os itens foram conferidos pelo código e por testes automatizados.

**Infraestrutura:** `docker-compose.yml`, `frontend/Dockerfile` e `frontend/deploy/nginx.conf` existem. A configuração do
Nginx foi testada; a construção das imagens no Docker ainda não foi validada.
