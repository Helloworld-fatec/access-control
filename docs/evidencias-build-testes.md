# Evidências de build e testes (backend e frontend)

Registro da execução de tipos, testes e build, das falhas corrigidas e dos achados encaminhados.
Executado em **23/11/2026**, na branch `feat/painel-integrado`.

## 1. Como reproduzir

Na máquina (sem banco para os testes, que usam o Prisma simulado):

```bash
# backend
cd backend
npm ci
npx prisma generate --config prisma7.config.ts
npm run typecheck
npm test

# frontend
cd ../frontend
npm ci
npm run check        # tipos + lint + testes
npm run build
```

No pipeline: `.github/workflows/ci.yml` roda os mesmos comandos em três jobs (`backend`, `frontend` e `docker compose`).
O job `docker compose` ainda **não foi executado** no GitHub (veja a seção 6).

## 2. Resultado da execução

| Verificação | Comando | Resultado |
| --- | --- | --- |
| Tipos do backend | `npm run typecheck` | Sem erros |
| Testes do backend | `npm test` | **118 passaram, 0 falharam** (9 arquivos) |
| Tipos, lint e testes do frontend | `npm run check` | **58 passaram, 0 falharam** (10 arquivos); lint sem avisos |
| Build do frontend | `npm run build` | Concluída em 4,3 s (JS 474 kB, 146 kB comprimido; CSS 11,7 kB) |
| Docker Compose | `docker compose config` | Válido com os segredos preenchidos; recusa subir sem eles |

Testes do backend por arquivo:

| Arquivo | Testes | O que cobre |
| --- | --- | --- |
| `access-decision.test.ts` | 44 | Credencial do terminal, decisão de acesso por NFC e por face, registro de cada tentativa |
| `qr-access.test.ts` | 21 | Login do app, QR (desconhecido, usado, vencido) e decisão de acesso por QR |
| `auth-login.test.ts` | 10 | Login: credenciais válidas e inválidas |
| `access-logs.test.ts` | 10 | Leitura do histórico: filtros, período em São Paulo, paginação, somente leitura |
| `access-logs-export.test.ts` | 8 | Exportação CSV (permissões, filtros, lotes, limite) |
| `csv.test.ts` | 13 | Escape do CSV, proteção contra fórmula, fuso |
| `dashboard.test.ts` | 8 | Rotas do painel e status dos terminais |
| `health.spec.ts`, `access.service.spec.ts` | 1 + 3 | Testes que já existiam no repositório |

## 3. Testes de autorização e logs: critérios atendidos

| Critério da tarefa | Como foi atendido |
| --- | --- |
| Cobrem credenciais válidas e inválidas | Login (senha errada, e-mail desconhecido, usuário inativo, corpo inválido, token válido/vencido/forjado), chave do terminal (ausente, curta, desconhecida, válida), tag NFC (cadastrada, desconhecida, desativada) e QR (desconhecido, usado, vencido) |
| Cobrem falhas relevantes | Todos os motivos de negação que a decisão de acesso produz (credencial inválida, usuário inativo, sem autorização, cancelada, fora do período, fora do horário, usos esgotados, QR repetido e QR vencido), a **corrida no último uso** e os pedidos inválidos (corpo incompleto, UID malformado, confiança facial fora de 0 a 1). Os motivos `TOO_FAR`, `FACE_LOW_CONFIDENCE` e `TERMINAL_OFFLINE` existem no tipo, mas nenhum controller os gera hoje, então não têm teste |
| Verificam a decisão central e o registro | Cada teste confere o motivo devolvido **e** que a tentativa gerou exatamente um registro (`AccessLog`) com usuário, terminal, método, resultado, motivo e autorização |
| Executam localmente e podem ser chamados pelo pipeline | `npm test` roda sem banco; o job `backend` do `ci.yml` chama o mesmo comando |
| Evidências revisáveis | Este documento, com comando, contagem e achados |

Regras conferidas pelos testes: o horário e a data usam **São Paulo** (15:00 em SP vale numa janela 14:00 a 16:00, mesmo sendo 18:00 em UTC); o último dia do período ainda vale; a chave do terminal e o QR são procurados pelo **hash SHA-256**, nunca em texto puro; o histórico não tem rota de gravação nem de exclusão.

### Os testes detectam erros de verdade

Verificação feita à mão no `access.controller.ts` (o arquivo foi restaurado depois de cada teste):

| Alteração proposital | Resultado |
| --- | --- |
| Período deixa de ser inclusivo (`>` vira `>=`) | 1 teste falhou |
| Deixa de registrar o log ao liberar | 4 testes falharam |
| Ignora o limite de usos | 1 teste falhou |

## 4. Falhas corrigidas

| Área | Falha | Correção |
| --- | --- | --- |
| backend | Erro 500 em tags, foto e histórico: os modelos do `schema.prisma` estavam em minúsculas e os controllers usavam PascalCase | Modelos renomeados mantendo as tabelas (`@@map`); ajuste em `qr-access.controller.ts` |
| backend | `npm run dev` e `npm start` não existiam | Scripts restaurados |
| backend | A API não iniciava sem `JWT_SECRET` e o `.env.example` não o citava | `.env.example` e documentação atualizados |
| backend | `docs/criar-tabelas.sql` antigo criava só a migração inicial | Novo SQL com as 4 migrações |
| backend | Mensagem de inicialização apontava `/health`; o endereço real é `/api/health` | Texto do log corrigido |
| frontend | Login chamava `/auth/login`, que não existe (404) | Passou a usar `POST /api/login` |
| frontend | A sessão caía quando o terminal respondia 401 | Só `UNAUTHORIZED` e `INVALID_TOKEN` encerram a sessão |
| infra | `docker-compose.yml` e `.env.docker.example` tinham senha do banco (`changeme`) e segredo JWT de exemplo, aceitos sem alteração | Sem valores padrão: o Compose recusa subir sem `POSTGRES_PASSWORD` e `JWT_SECRET` |
| infra | Sem como saber se os serviços estavam prontos; logs sem limite | `healthcheck` nos três serviços, front só sobe com backend saudável, rotação de logs, banco sem porta publicada |
| entrega | O `.env.mock` ficou fora do zip e o modo demonstração dava erro 500 | Arquivo incluído e explicado no README |

## 5. Achados encaminhados (não corrigidos aqui)

Estes pontos estão em código de outros módulos e ficam com os respectivos responsáveis.

| # | Achado | Gravidade | Onde | Situação |
| --- | --- | --- | --- | --- |
| 1 | Um terminal com chave válida pode registrar acessos **em nome de outro terminal**, porque `validateNfcAccess` e `validateFaceAccess` usam o `terminalId` do corpo e ignoram o terminal autenticado (`req.terminal`) | Alta | `backend/src/controllers/access.controller.ts` | Descrito pelo teste `it.fails` "terminal não pode registrar acesso em nome de outro terminal". Passa enquanto o erro existe; quando corrigirem, troque `it.fails` por `it`. Correção sugerida: rejeitar com 403 quando `req.terminal.id !== dto.terminalId` |
| 2 | QR desconhecido responde 401 e **não gera registro** no histórico | Baixa | `qr-access.controller.ts` | Pode ser intencional (não há terminal conhecido para associar). Confirmar com o grupo |
| 3 | `users`, `locations` e `GET /access-logs` estão sem JWT | Decisão do grupo | `routes/index.ts` | Combinado deixar para depois. Antes de ligar, conferir se os apps mobile e o terminal usam essas rotas sem token |
| 4 | O código de `validateFaceAccess` troca os `userId` `demo-face-user` e `simulated-user` por outro usuário com autorização | Baixa hoje | `access.controller.ts` | Hoje não é alcançável, porque o schema exige UUID (há teste que confirma o 400). Se o schema mudar, vira uma brecha. Recomenda-se remover esse trecho |

## 6. Limitações

- **Docker:** as imagens **não foram construídas** neste ambiente (sem acesso ao Docker Hub). Foram validados a sintaxe do Compose, a recusa sem segredos e o Nginx. A construção e o teste de integração ficam no job `docker compose` do CI, que **ainda não rodou no GitHub**: conferir o resultado no primeiro Pull Request.
- **Testes do backend:** usam o Prisma simulado. Eles provam a lógica de decisão e de registro, mas não o SQL real. A integração com PostgreSQL de verdade foi conferida à mão antes (login, painel, CRUDs, exportação e acessos pelo terminal).
- **Cobertura:** não foi medida em porcentagem.
- **Testes E2E (US-20):** continuam pendentes (Playwright).
