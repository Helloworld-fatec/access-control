# frontend

Interface web de administração do **access-control** (React, TypeScript e Vite).
Cobre o Épico 6 do `scrum/BACKLOG.md`. Identidade visual nas cores da Fatec:
azul petróleo `#31566A`, vermelho `#B51F2E`, off-white `#F7F7F4` e cinza azulado `#E5EBEE`.

## Como rodar

Use a versão de Node indicada em `.node-version`, também usada no CI.

```bash
cp .env.example .env     # ajuste BACKEND_URL se o backend não estiver em localhost:3000
npm ci
npm run dev              # http://localhost:5173
```

O Vite encaminha `/api` para o backend, então o front usa caminho relativo e não depende de IP.
Para subir Express, PostgreSQL e o serviço facial em ambiente de teste, siga a seção de execução do [roteiro local](../docs/demonstracao-mobile-readings.md).

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

## Integração com o backend real

- Login administrativo em `POST /api/login`. Usuários, locais, autorizações, histórico e painel usam o JWT da sessão.
- O monitor consulta `GET /api/terminals/status` com JWT de administrador ativo. O status individual do equipamento em `GET /api/terminals/:id/status` usa a chave do terminal.
- Um `401` de autenticação encerra a sessão que originou a requisição. Um `403` informa falta de permissão e mantém a sessão.
- O histórico em `GET /api/access-logs` lista registros QR, facial e NFC com filtros e paginação.
- O backend devolve texto vazio em alguns campos opcionais (ex.: descrição do local); o front mostra "—".

A build foi validada em Edge headless com Express, PostgreSQL descartável e o serviço facial local. O teste cobriu login, painel, locais, autorizações, criação de terminal e a exibição de registros QR e faciais. A rotação foi verificada pela API administrativa.

## Backend

O front usa os endpoints do backend deste repositório.

- **Login:** `POST /api/login` → `{ accessToken, tokenType, expiresIn, user }`. O token vai em `Authorization: Bearer`.
  Só administradores entram. O token dura `JWT_EXPIRES_IN` (padrão 1h) e **não há renovação** (`/auth/refresh` não existe):
  ao expirar, o front volta ao login com a mensagem "Sua sessão expirou".
- **Autorizações:** o administrador que cria ou cancela vem do token; o front não envia `createdById` nem `canceledById`.
- No `.env` do backend é preciso `JWT_SECRET` com **pelo menos 32 caracteres**.

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
um terminal conta como online no monitor quando registrou contato com a API nos últimos 2 minutos (`lastSeenAt`).
O estado da trava não existe no backend: o cartão só o mostra no modo demonstração (`npm run dev:mock`).

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

A tag é vinculada por UID digitado ou por leitor USB que emula teclado, que é o que o backend aceita hoje
(`POST /users/{id}/tags` com o UID). A **Web NFC API não é usada**: ela só funciona no Chrome para Android e exige HTTPS.

> O backlog da US-07 foi atualizado: agora pede "Gravar tag" pelo terminal, com a situação da tag
> (pendente, ativa, falha, revogada) e sem leitor USB. Isso depende de endpoints que o backend ainda não tem
> (`GET /users/{id}/tags` e a gravação pelo terminal). Ao implementá-los, trocar o formulário de UID por esse fluxo.

## Pendências

- Exportação CSV no backend real, rotação de chave pela interface web, paginação dos seletores auxiliares e limpeza de campos opcionais na edição.
- Cadastro facial pela web. O cadastro oficial é feito no Mobile Registry.
- Validar o ambiente hospedado com a URL real de `/api`, o proxy ou `config.json`, o login administrativo e os registros do histórico.
