# Documentação da API

API REST do backend do access-control (Node.js, Express 5, TypeScript, Prisma e PostgreSQL). Este documento descreve o que está implementado na `main` em 15/11/2026, lido diretamente do código em `backend/src/routes` e `backend/src/controllers`. A decisão de acesso é sempre do backend.

- **URL base:** `http://localhost:3000/api` (a porta vem da variável `PORT`)
- **Formato:** JSON, exceto o envio de rosto e foto, que usa `multipart/form-data`
- **Horário:** as regras de horário usam o fuso `America/Sao_Paulo`

## Convenções

### Formas de autenticação

| Tipo | Como enviar | Onde vale |
|---|---|---|
| Público | nenhuma | `GET /api/health`, `POST /api/login` |
| JWT | `Authorization: Bearer <accessToken>` (token do `POST /api/login`) | `POST /api/access/qr/consume`, `GET /api/authorizations/me` |
| Administrador | JWT de um usuário ativo com perfil `ADMIN` | rotas de autorizações e de terminais (gerenciamento) |
| Terminal | cabeçalho `X-Terminal-Key` (ou `X-API-Key`, ou `Authorization: Bearer` com 24 caracteres ou mais) com a chave do terminal | QR, status, rostos, leitura de NFC e de rosto |

A chave do terminal é gerada na criação (`POST /api/terminals`) e aparece **uma única vez** na resposta. O backend guarda só o hash.

Hoje as rotas de **usuários**, **locais** e **histórico de acessos** **não exigem autenticação** (no código, a linha `routes.use(authenticate)` está comentada). Veja a seção "Limitações conhecidas".

### Erros

Todo erro segue o mesmo formato:

```json
{ "error": { "code": "INVALID_CREDENTIALS", "message": "E-mail ou senha inválidos", "details": null } }
```

Erros de validação respondem `400` com `code: "VALIDATION_ERROR"` e `details` com a lista de campos (`path` e `message`). Rota inexistente responde `404` com `code: "NOT_FOUND"`.

### Paginação

As listagens aceitam `page` (padrão 1) e `pageSize` (de 1 a 100, padrão 20) e respondem:

```json
{ "data": [], "page": 1, "pageSize": 20, "total": 0, "totalPages": 1 }
```

### Formatos

- Datas: `AAAA-MM-DD`. Horários: `HH:mm`, 24 horas.
- Identificadores: UUID.
- UID de tag NFC: hexadecimal em maiúsculas, sem separadores, de 8 a 20 caracteres. O backend normaliza `04:a3:2f:1b` para `04A32F1B`.
- Perfis de usuário: `ADMIN`, `RESIDENT` (condômino), `VISITOR` (visitante).

## Saúde e informações

| Método | Rota | Auth | Resposta |
|---|---|---|---|
| GET | `/api/health` | público | `{ "status": "ok", "timestamp": "..." }` |
| GET | `/api` e `/` | público | informações da API (JSON) ou página de boas-vindas (navegador) |

## Autenticação

### POST `/api/login`

Corpo: `{ "email": "...", "password": "..." }`

Resposta `200`:

```json
{
  "accessToken": "<jwt>",
  "tokenType": "Bearer",
  "expiresIn": "1h",
  "user": { }
}
```

O JWT leva o perfil no campo `role` e o id do usuário em `sub`. A duração vem de `JWT_EXPIRES_IN` (padrão `1h`). Não há renovação de token. Usuário inativo ou senha errada: `401 INVALID_CREDENTIALS`.

## Usuários

| Método | Rota | Descrição |
|---|---|---|
| GET | `/api/users` | Lista com `page`, `pageSize`, `search` (nome ou documento), `role` e `active` (`true` ou `false`) |
| POST | `/api/users` | Cria usuário |
| GET | `/api/users/:id` | Detalha |
| PUT | `/api/users/:id` | Atualiza (envie ao menos um campo) |
| PATCH | `/api/users/:id/status` | Ativa ou desativa: `{ "active": true }` |
| POST | `/api/users/:id/tags` | Vincula tag NFC: `{ "uid": "04A32F1B" }` |
| DELETE | `/api/users/:id/tags/:tagId` | Remove a tag |
| POST | `/api/users/:id/face` | Cadastra ou atualiza o rosto (`multipart/form-data`: `embedding` em JSON, `modelVersion`, `consent` e, opcional, `photo` em JPEG) |
| DELETE | `/api/users/:id/face` | Remove o rosto |
| GET | `/api/users/:id/photo` | Devolve a foto |

Corpo de criação: `name` (2 a 120 caracteres), `email`, `password` (6 a 72), `role` e, opcionais, `document` (até 30) e `phone` (até 20). `email` e `document` são únicos.

## Locais

Local é a combinação de edifício, portaria, porta e catraca.

| Método | Rota | Descrição |
|---|---|---|
| GET | `/api/locations` | Lista com `page`, `pageSize` e `search` |
| POST | `/api/locations` | Cria: `building` (obrigatório) e, opcionais, `entrance`, `door`, `turnstile`, `description` |
| GET | `/api/locations/:id` | Detalha |
| PUT | `/api/locations/:id` | Atualiza |
| DELETE | `/api/locations/:id` | Remove |

## Terminais

### Rotas do próprio terminal (credencial do terminal)

| Método | Rota | Descrição |
|---|---|---|
| POST | `/api/terminals/me/qr` | Emite um QR de uso único. Resposta: `{ "payload": { "v": 1, "token": "<43 caracteres>" }, "expiresAt": "...", "refreshAfterSeconds": 200 }`. Limite de 30 requisições por minuto |
| GET | `/api/terminals/:id/qr` | Emite um token assinado com HMAC. Resposta: `{ "token": "<payload>.<assinatura>", "expiresAt": "...", "ttlSeconds": 10 }` |
| GET | `/api/terminals/:id/status` | `{ id, online, presence, presenceActive, lastPresenceAt, lastSeenAt }`. A presença conta como ativa por 5 segundos |
| GET | `/api/terminals/:id/faces` | `{ "data": [...] }` com os embeddings faciais dos usuários autorizados no local |

O `:id` precisa ser o do próprio terminal; outro id responde `403 TERMINAL_FORBIDDEN`.

### Gerenciamento (administrador)

| Método | Rota | Descrição |
|---|---|---|
| GET | `/api/terminals` | Lista com `page`, `pageSize` e `locationId` |
| POST | `/api/terminals` | Cria: `name`, `locationId`, `latitude`, `longitude`. Resposta `201` com o terminal e a `apiKey` (única vez) |
| GET | `/api/terminals/:id` | Detalha |
| PUT | `/api/terminals/:id` | Atualiza (parcial) |
| DELETE | `/api/terminals/:id` | Remove (`204`) |

## Autorizações

| Método | Rota | Auth | Descrição |
|---|---|---|---|
| GET | `/api/authorizations/me` | JWT | Autorizações do usuário logado |
| GET | `/api/authorizations` | admin | Lista com `page`, `pageSize`, `userId`, `locationId`, `status` (`ACTIVE`, `CANCELED`, `EXPIRED`), `from` e `to` (período que intersecta o intervalo) |
| POST | `/api/authorizations` | admin | Cria |
| GET | `/api/authorizations/:id` | admin | Detalha |
| PATCH | `/api/authorizations/:id/cancel` | admin | Cancela |

Corpo de criação:

```json
{
  "userId": "<uuid>",
  "locationId": "<uuid>",
  "startDate": "2026-11-16",
  "endDate": "2026-11-30",
  "startTime": "08:00",
  "endTime": "18:00",
  "maxUses": 20
}
```

`maxUses` é opcional (sem valor, os usos são ilimitados). O administrador que cria ou cancela vem do token, e não do corpo. A data final não pode ser anterior à inicial, e o horário final precisa ser posterior ao inicial. `EXPIRED` é calculada na consulta, quando a data final já passou.

## Acesso

### POST `/api/access/qr/consume` (JWT)

O app do usuário envia o QR lido: `{ "token": "<43 caracteres>" }`. Limite de 20 requisições por minuto por usuário e IP. O backend:

1. Marca o QR como consumido de forma atômica (QR repetido é negado como `REPLAYED_CREDENTIAL`).
2. Confere a validade do QR, se o usuário está ativo e se existe autorização para o local do terminal, dentro do período, do horário e dos usos restantes.
3. Registra a tentativa em todo caso.

| Resultado | Resposta |
|---|---|
| Liberado | `200` `{ "result": "GRANTED", "accessLogId", "terminalId", "authorizationId" }` |
| Negado | `403` `{ "result": "DENIED", "reason": "<motivo>", "accessLogId" }` |
| QR desconhecido | `401` `INVALID_CREDENTIAL` |

### POST `/api/access/nfc` (terminal)

Corpo: `{ "terminalId": "<uuid>", "uid": "04A32F1B" }`. Tag desconhecida ou inativa responde `403` com `{ "result": "DENIED", "allowed": false, "reason": "INVALID_CREDENTIAL", "message": "..." }`. Nos demais casos, aplica as mesmas regras de autorização do QR.

### POST `/api/access/face` (terminal)

Corpo: `{ "terminalId": "<uuid>", "userId": "<uuid>", "confidence": 0.93 }`, com `confidence` entre 0 e 1. O reconhecimento facial é uma funcionalidade extra.

### Motivos de negação

| Código | Significado |
|---|---|
| `INVALID_CREDENTIAL` | Credencial inválida ou não cadastrada |
| `EXPIRED_CREDENTIAL` | QR expirado |
| `REPLAYED_CREDENTIAL` | QR já utilizado |
| `USER_INACTIVE` | Usuário inativo |
| `NO_AUTHORIZATION` | Sem autorização para o local |
| `AUTHORIZATION_CANCELED` | Autorização cancelada |
| `OUTSIDE_PERIOD` | Fora das datas da autorização |
| `OUTSIDE_SCHEDULE` | Fora do horário da autorização |
| `USES_EXHAUSTED` | Limite de usos atingido |
| `TOO_FAR` | Definido, mas ainda não usado (ver limitações) |
| `FACE_LOW_CONFIDENCE` | Confiança facial insuficiente |
| `TERMINAL_OFFLINE` | Terminal indisponível |

## Histórico de acessos

### GET `/api/access-logs`

Filtros: `userId`, `terminalId`, `method` (`QR`, `NFC` ou `FACE`), `result` (`GRANTED` ou `DENIED`), `from`, `to` (`AAAA-MM-DD`), `page` e `pageSize`. Toda tentativa de acesso, liberada ou negada, gera um registro.

## Limitações conhecidas

Registradas aqui para não haver diferença entre o que a documentação diz e o que o código faz.

1. **MQTT ainda é simulado no backend.** A liberação chama `requestDoorUnlock`, que apenas escreve `[MQTT SIMULADO]` no log. O backend não tem cliente MQTT, e a integração com o ESP32 é trabalho da Sprint 3 (contrato em [`contrato-mqtt.md`](./contrato-mqtt.md)).
2. **A distância até o terminal não é validada.** O motivo `TOO_FAR` existe, mas nenhuma rota o usa, e o `/access/qr/consume` não recebe a localização do celular. O terminal guarda `latitude` e `longitude`.
3. **Dois formatos de QR coexistem.** `POST /terminals/me/qr` gera um token de 43 caracteres válido por 300 segundos e é o único aceito por `/access/qr/consume`. `GET /terminals/:id/qr` gera um token assinado, com validade de 10 segundos, em outro formato, que o `/access/qr/consume` rejeita. A arquitetura prevê renovação a cada 10 segundos.
4. **Usuários, locais e histórico não exigem login.** Qualquer cliente que alcance a API pode listar e alterar esses recursos.
