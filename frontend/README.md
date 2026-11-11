# frontend

Interface web de administração do **access-control** (React, TypeScript e Vite).
Cobre o Épico 6 do `scrum/BACKLOG.md`. Identidade visual nas cores da Fatec, a mesma paleta do mobile-user:
azul petróleo `#31566A`, vermelho `#B51F2E`, off-white `#F7F7F4` e cinza azulado `#E5EBEE`.

## Como rodar

```bash
cp .env.example .env     # ajuste BACKEND_URL se o backend não estiver em localhost:3000
npm install
npm run dev              # http://localhost:5173
```

O Vite encaminha `/api` para o backend, então o front usa caminho relativo e não depende de IP.

### Sem backend (modo demonstração)

```bash
npm run dev:mock
```

A API é simulada no navegador, com dados de exemplo. Entre com **admin@teste.com** e qualquer senha.
Os dados voltam ao início ao recarregar a página. O código está em `src/shared/mock.ts` e não entra na build normal.

### Qualidade

```bash
npm run typecheck   # tipos
npm run lint        # ESLint (inclui a proibição de dangerouslySetInnerHTML)
npm test            # Vitest + Testing Library + MSW
npm run check       # os três, em sequência
```

## Backend

O front usa os endpoints do backend da branch `develop`:

- **Login:** `POST /api/login` → `{ accessToken, tokenType, expiresIn, user }`. O token vai em `Authorization: Bearer`.
  Só administradores entram. O token dura `JWT_EXPIRES_IN` (padrão 1h) e **não há renovação** (`/auth/refresh` não existe):
  ao expirar, o front volta ao login com a mensagem "Sua sessão expirou".
- **Autorizações:** o administrador que cria ou cancela vem do token; o front não envia `createdById` nem `canceledById`.
- Se o backend for antigo e responder 404 em `POST /login`, o front entra em *modo de desenvolvimento*:
  acha o administrador pelo e-mail e **não confere a senha** (há um aviso na tela). Desligue com `VITE_DEV_AUTH=false`.
- No `.env` do backend é preciso `JWT_SECRET` com **pelo menos 32 caracteres**.

## Painel (dashboard)

Tela inicial após o login (`/painel`), com resumo do dia, gráfico de acessos por hora (Recharts, com tabela equivalente
para leitores de tela), acessos por método, motivos de negação, autorizações, status dos terminais e últimos acessos.
Os terminais e os últimos acessos atualizam sozinhos a cada 5 segundos, com opção de pausar.

**Por enquanto o painel só mostra dados no modo demonstração (`npm run dev:mock`).** O backend não foi alterado e ainda
não tem os endpoints abaixo; com o backend real, o painel mostra uma mensagem explicando o que falta e continua funcionando
a lista de últimos acessos (`GET /access-logs`).

Contrato que o front espera (proposta para quem fizer o backend):

| Endpoint | Resposta |
| --- | --- |
| `GET /dashboard/summary?date=AAAA-MM-DD` | `{ date, granted, denied, denialRate (0 a 1), byMethod: {QR, NFC, FACE}, authorizations: {active, expiringSoon, canceled}, topDenialReasons: [{reason, count}] }` |
| `GET /dashboard/accesses-by-hour?date=AAAA-MM-DD` | `[{ hour (0 a 23), granted, denied }]`, 24 itens, hora em America/Sao_Paulo |
| `GET /terminals/{id}/status` | o que já existe (`online`, `presenceActive`, `lastPresenceAt`, `lastSeenAt`), acrescido de `lock: "LOCKED" \| "UNLOCKED"`, e acessível ao administrador (hoje exige a chave do terminal) |

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
- **Foto:** buscada por requisição autenticada e exibida via `URL.createObjectURL` (a tag `<img>` não envia o token).
- **HTTP na LAN de demonstração:** funciona, mas o tráfego não é cifrado (limitação aceita para a demonstração).
  Em HTTP fora de `localhost`, o navegador desativa o botão **Copiar chave** do terminal; a chave continua visível
  para copiar à mão.

## Tag NFC

A tag é vinculada por UID digitado ou por leitor USB que emula teclado (o UID "cai" no campo de texto).
A **Web NFC API não é usada**: ela só funciona no Chrome para Android e exige HTTPS.

## Situação das user stories

Veja `criterios-de-aceite-frontend.md` (na raiz da entrega) para cada critério. Resumo do que ainda não existe:

- Painel (US-15, US-16): pronto no front, mas só com dados de demonstração até o backend ter os endpoints acima.
- Exportação do histórico (US-14): falta endpoint no backend.
- Foto por upload ou webcam (US-08).
- Teste ponta a ponta com Playwright (US-20); os testes unitários e de componentes já existem.
- Nginx e Dockerfile (épico de DevOps).
