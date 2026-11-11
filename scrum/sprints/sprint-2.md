# Sprint 2

Registro da segunda sprint do projeto access-control: meta, resultado, entregas por serviço, Pull Requests, pendências e impedimentos. A posição é a de 10/11/2026, véspera da Sprint Review 2. As seções da review e da retrospectiva serão preenchidas depois dela.

| Item | Valor |
|---|---|
| Período | 22/10/2026 a 11/11/2026 |
| Sprint Review | 11/11/2026, 19h30 |
| Product Owner | Bruno |
| Scrum Master | Suelen |
| Professor | Leandro Toss Hoffmann |
| **Resultado parcial (planilha de 10/11)** | **63 de 79 tarefas concluídas, 510 de 647 pontos (79%)** |

## 1. Meta da sprint

Fluxos de acesso por QR Code e NFC integrados entre os apps, o backend e o ESP32, incorporando o que o professor pediu na Sprint Review 1: sensor infravermelho, display, QR Code e GPS no terminal (ver [`sprint-1.md`](./sprint-1.md), seção 6).

## 2. Resultado do sprint backlog

Fonte: planilha Sprint-Backlog, uma aba por pessoa. A pontuação de cada tarefa é **4 + dificuldade + prioridade** (fórmula da própria planilha). As tarefas também estão no banco "Backlog do Projeto", no Notion.

| Responsável | Serviço | Tarefas | Concluídas | Em andamento ou pendentes | Pontos planejados | Pontos concluídos |
|---|---|---|---|---|---|---|
| Ryan | mobile-registry | 36 | 22 | 14 | 292 | 175 |
| Pedro | frontend | 20 | 20 | 0 | 165 | 165 |
| Bruna | device-esp32 | 10 | 9 | 1 | 92 | 82 |
| Nicolas | mobile-readings e rotas do backend | 8 | 7 | 1 | 64 | 54 |
| Bruno | backend, mobile-user e contrato de comunicação | 5 | 5 | 0 | 34 | 34 |
| Alicia | diagrama de caso de uso e testes do backend | | | | | |
| Suelen | Scrum e documentação | | | | | |
| **Total na planilha** | | **79** | **63** | **16** | **647** | **510** |

- Alicia entrou no time em 02/11 e a aba dela ainda não tem tarefas. As entregas dela estão nas Pull Requests #18 e #19 (seção 5).
- A aba da Suelen não tem tarefas da Sprint 2. As entregas de documentação estão na seção 3.
- Na planilha, todas as tarefas da Sprint 1 aparecem concluídas, inclusive as pendências que passaram para esta sprint: o login das rotas protegidas do frontend (Pedro) e as da Bruna.
- Já há tarefas planejadas para a Sprint 3: 8 do Nicolas (mobile-readings), 64 pontos, todas pendentes.

## 3. O que cada serviço entregou

| Serviço | Responsável | Entregas |
|---|---|---|
| mobile-registry | Ryan | Login restrito a administrador, com token em armazenamento seguro, verificação de sessão ativa, tratamento de token expirado e logout. Lista de usuários paginada, com busca por nome ou documento, filtro por perfil e estados de carregamento, vazio e erro. Formulário de cadastro com validações e erros do backend exibidos no campo. Tela de detalhes e edição com confirmação de salvamento. Ativação e desativação de usuário com confirmação prévia, e usuários inativos identificados na lista |
| frontend | Pedro | Painel com resumo do dia, taxa de negação, acessos por hora e por método (QR, NFC e facial), cartões de autorizações ativas, expirando e canceladas e motivos de negação mais frequentes. Últimos acessos com atualização automática (polling) e cartão por terminal com conexão, presença e trava. Endereço da API em `config.json`, sem rebuild. Contraste medido (WCAG AA), foco visível e layout para telas estreitas. Bloqueio de `dangerouslySetInnerHTML` por ESLint. Documentação de HTTP, HTTPS, CORS e LGPD. Testes com Vitest, Testing Library e MSW e comando `npm run check` |
| device-esp32 | Bruna | Simulação do terminal com ESP32 no Wokwi, com o fluxo de estados testado por comandos no Monitor Serial. Ambiente do ESP32 físico configurado, pinagem registrada, jumpers padronizados e componentes montados na protoboard. Componentes testados individualmente e depois integrados no firmware de bancada, com autorização simulada e sem backend. Presença confirmada por três segundos com o sensor infravermelho, no lugar do ultrassônico, e QR Code exibido no OLED físico, decodificado por fotografia (a leitura direta pela câmera depende de ajuste) |
| mobile-readings e backend | Nicolas | Tópicos MQTT atualizados para o contrato v1, novo payload JSON de presença, assinatura do tópico de decisão de acesso, exibição do QR Code para leitura pelo mobile-user, simulação de eventos de hardware no modo web e desktop e suíte de testes atualizada. No backend, headers de autenticação do terminal |
| backend, mobile-user e contrato | Bruno | Rotas de criação de QR Code para exibição no dispositivo, rotas e middleware de autenticação, ajuste de estilo do mobile-user e o contrato de comunicação entre os serviços ([`docs/contrato-mqtt.md`](../../docs/contrato-mqtt.md)) |
| documentação e Scrum | Suelen | Documento da Sprint 1 (PR #10), inclusão da Alicia no time (PR #11) e organização das tarefas da planilha no Notion |
| diagrama de caso de uso e testes do backend | Alicia | Diagrama de caso de uso (PR #18) e testes do backend com Vitest (PR #19), ambos mergeados em 10/11 |

## 4. Em andamento

| Serviço | Responsável | O que falta |
|---|---|---|
| mobile-registry | Ryan | 14 tarefas (117 pontos). Cadastro em etapas (progresso, navegação condicional, tela de revisão e envio sequencial) e fluxo de tags: botão "Gravar tag", situação de cada tag (pendente, ativa, falha ou revogada), revogação, substituição, mensagem de terminal offline ou ocupado e garantia de que o código gravado nunca é exibido |
| device-esp32 | Bruna | Diagnóstico do leitor RC522 físico (em andamento): alimentação, pinagem e leitura testadas, com possível falha de soldagem. Passam para a próxima sprint a revisão e a integração do RC522, os testes do GPS, a comunicação com o backend via MQTT, a montagem do suporte físico ou maquete e o ajuste do QR Code para leitura direta pelo celular |
| backend | Nicolas | Integração do fluxo de unlock com a publicação MQTT (em andamento) |

## 5. Pull Requests da sprint

| PR | Título | Autoria | Situação | Data |
|---|---|---|---|---|
| #10 | docs(sprint-1): registra resultado, review e feedback do professor | Suelen-Castro | mergeado | 26/10 |
| #11 | docs: adiciona Alicia ao time (diagrama de caso de uso e testes do backend) | Helloworld-fatec | mergeado | 08/11 |
| #12 | update (backend, frontend, mobile-readings e docs, 100 arquivos) | BrunoBerval | mergeado | 08/11 |
| #13 | Mobile user/app acesso | Helloworld-fatec | fechado sem merge | 08/11 |
| #14 | Mobile user/app acesso (backend, 5 arquivos) | BrunoBerval | mergeado | 08/11 |
| #15 | docs: device-esp32 - contrato mqtt | Helloworld-fatec | mergeado | 08/11 |
| #16 | update (docs) | Helloworld-fatec | mergeado em `develop` | 08/11 |
| #17 | feat(frontend): painel, paleta Fatec, detalhe de autorização, testes | PedroJesusFr | mergeado em `develop` | 10/11 |
| #18 | DIAGRAMA_DE_CASO_DE_USO | TIALICIA | mergeado | 10/11 |
| #19 | feat(backend): adiciona testes unitarios e integracao com vitest | TIALICIA | mergeado | 10/11 |
| #20 | docs(sprint-2): registra resultado parcial, entregas, PRs e impedimentos da Sprint 2 | Helloworld-fatec | mergeado | 10/11 |
| #21 | Atualização da main (leva o conteúdo da `develop`, incluindo o painel do frontend) | Helloworld-fatec | mergeado | 10/11 |

## 6. Impedimentos e pontos de alinhamento

1. **Arquitetura e contrato divergem.** [`docs/arquitetura.md`](../../docs/arquitetura.md) descreve tópicos `terminal/{id}/...`, com o ESP32 lendo e gravando a tag NFC e o sensor HC-SR04. O contrato v1 ([`docs/contrato-mqtt.md`](../../docs/contrato-mqtt.md)) usa `access/v1/terminals/{terminalId}/...`, com os tópicos `presence`, `door/state`, `access/request` e `access/decision`, e está marcado como rascunho para validação. A Bruna já testou o sensor infravermelho no lugar do ultrassônico.
2. **Leitor RC522 e GPS.** O RC522 físico segue em diagnóstico, com possível falha de soldagem, e a validação final aguarda a avaliação do professor. O teste do GPS passa para a próxima sprint.
3. **Compilação lenta no mobile-registry.** O tempo de compilação do app é extremamente lento, o que atrasa os testes das tarefas em andamento (relato do Ryan).
4. **Fluxo de gravação de tag.** Depende do terminal e do backend em MQTT: o botão "Gravar tag" do mobile-registry e o unlock por MQTT do backend ainda estão em andamento.
5. **Planilha.** As abas da Alicia e da Suelen não têm tarefas da Sprint 2, e a pontuação delas não entra no total acima.

## 7. Sprint Review 2

Data: 11/11/2026, 19h30.

Feedback do professor: a registrar depois da review.

## 8. Retrospectiva

A registrar depois da review.
