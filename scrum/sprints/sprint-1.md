# Sprint 1

- **Kick-off do projeto:** 30/09/2026
- **Sprint Review 1:** 21/10/2026, 19h30
- **Planning:** 07/10/2026, realizado em grupo; registro feito retroativamente neste arquivo.

## Meta da sprint

Cada serviço com o **início do código** no repositório (estrutura base e primeiras funcionalidades), além da documentação e da organização do time prontas.

Meta definida com o Product Owner: a Sprint 1 é a base. A entrega final do projeto deve ter todos os serviços funcionando.

## Sprint backlog

### Scrum / documentação (Suelen)

| US | Task | Etapa |
|---|---|---|
| US-01 | Definir papéis e responsável por serviço | concluído |
| US-01 | Definir horários das cerimônias | em andamento |
| US-03 | Redigir DoR e DoD | a fazer |
| US-05 | Criar quadro e issues da Sprint 1 | a fazer |
| US-02 | Refinar backlog e levantar estimativas | a fazer |
| US-04 | Registrar meta e sprint backlog | a fazer |
| US-09 | Criar registro de riscos e decisões em aberto | a fazer |
| US-10 | Levar dúvidas ao professor e registrar respostas | a fazer |
| US-11 | Revisar arquitetura (facial obrigatória x extra) | a fazer |
| US-18 | README raiz inicial | a fazer |
| US-07 | Roteiro da Sprint Review 1 | a fazer |

### Já entregue (Bruno)

- Repositório e estrutura de pastas
- Backlog do projeto em `scrum/BACKLOG.md`
- Scaffolding do backend (Express, Prisma, Zod) e primeiro schema
- Models, DTOs, controllers e rotas
- Middleware de upload de fotos
- Deploy da primeira versão do backend na plataforma Render

### Demais serviços

A preencher pelos responsáveis: mobile-readings (Nick), mobile-registry (Ryan), mobile-user (Bruno), device-esp32 (Bruna), frontend (Pedro).

### mobile-readings e backend de leitura (Nicolas)

**Épico 2 — `mobile-readings` (App Terminal de Acesso):**

| US | Task | Etapa |
|---|---|---|
| US-01 | Estrutura base do projeto Flutter em camadas (`config`, `models`, `services`, `state`, `screens`) | concluído |
| US-02 | Tela de configuração do terminal com persistência (`shared_preferences` e `flutter_secure_storage`) | concluído |
| US-03 | Cliente HTTP único com autenticação por `x-api-key`, timeout e retry automático | concluído |
| US-04 | Máquina de estados do terminal (`Repouso`, `Escuta`, `Validando`, `Liberado`, `Negado`) | concluído |
| US-05 | Serviço MQTT assinando o tópico `terminal/{id}/presence` no broker Mosquitto | concluído |
| US-06 | Fallback automático de presença por polling HTTP (`GET /terminals/{id}/status`) | concluído |
| US-07 | Exibição e renovação automática do QR Code rotativo a cada 10s | concluído |
| US-08 | Invalidação imediata do QR Code em falha de conexão ("QR indisponível") | concluído |
| US-09 | Leitura nativa de tag NFC e padronização do UID em hexadecimal maiúsculo | concluído |
| US-10 | Envio da tag NFC (`POST /access/nfc`) com bloqueio de leituras repetidas (*cooldown*) | concluído |
| US-11 | Feedback visual acessível de acesso liberado (verde) e negado (vermelho) | concluído |
| US-12 | Comportamento seguro *fail-closed* sem conexão com o backend | concluído |
| US-13 | Modo de repouso e desligamento de recursos fora do estado de escuta | concluído |
| US-14 | Execução como terminal dedicado (orientação fixa e `wakelock_plus`) | concluído |
| US-15 / US-17 | Serviço de sincronização de embeddings faciais em memória e cálculo de similaridade | concluído |
| US-20 | Interface de alto contraste com instruções claras de uso | concluído |
| US-21 | Testes automatizados unitários e de widget (11 testes passando + `flutter analyze`) | concluído |

**Épico 5 — `backend` (Rotas de suporte ao Terminal de Acesso):**

| US | Task | Etapa |
|---|---|---|
| US-09 | Middleware `requireTerminalAuth` para validação de `apiKey` (SHA-256) do terminal | concluído |
| US-11 | Rota `GET /api/terminals/:id/qr` gerando token assinado (HMAC-SHA256) e `QrNonce` anti-replay | concluído |
| US-12 | Núcleo de decisão de acesso e rota `POST /api/access/nfc` com registro em `AccessLog` | concluído |
| US-14 | Rotas `GET /api/terminals/:id/faces` e `POST /api/access/face` | concluído |
| US-16 | Rota `GET /api/terminals/:id/status` para consulta de presença e estado online | concluído |

## Impedimentos e riscos

Ver [RISCOS.md](../RISCOS.md).

## Review

*(preencher em 21/10)*

## Retrospectiva

*(preencher após a review)*
