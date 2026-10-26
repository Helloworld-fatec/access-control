# Sprint 1

Registro da primeira sprint do projeto access-control: meta, resultado, entregas, Sprint Review com o feedback do professor, pontos de alinhamento e pendências que passam para a Sprint 2.

| Item | Valor |
|---|---|
| Período | 30/09/2026 (kick-off) a 21/10/2026 |
| Planning | 07/10/2026, realizado em grupo |
| Sprint Review | 21/10/2026, 19h30 |
| Formato da review | Apresentação de slides, sem demonstração ao vivo |
| Product Owner | Bruno |
| Scrum Master | Suelen |
| Professor | Leandro Toss Hoffmann |
| **Resultado** | **85 de 90 tarefas concluídas, 650 de 690 pontos (94%)** |

## 1. Meta da sprint

Cada serviço com o **início do código** no repositório (estrutura base e primeiras funcionalidades), além da documentação e da organização do time prontas.

Meta definida com o Product Owner: a Sprint 1 é a base. A entrega final do projeto deve ter todos os serviços funcionando.

## 2. Resultado do sprint backlog

Fonte: planilha Sprint-Backlog, uma aba por pessoa. A pontuação de cada tarefa é **4 + dificuldade + prioridade** (fórmula da própria planilha).

| Responsável | Serviço | Tarefas | Concluídas | Pontos planejados | Pontos concluídos |
|---|---|---|---|---|---|
| Ryan | mobile-registry | 24 | 24 | 180 | 180 |
| Nicolas | mobile-readings e rotas do backend | 14 | 14 | 106 | 106 |
| Bruna | device-esp32 | 16 | 12 | 135 | 103 |
| Pedro | frontend | 12 | 11 | 95 | 87 |
| Bruno | backend, mobile-user e repositório | 13 | 13 | 89 | 89 |
| Suelen | Scrum e documentação | 11 | 11 | 85 | 85 |
| **Total** | | **90** | **85** | **690** | **650** |

## 3. O que cada serviço entregou

| Serviço | Responsável | Entregas |
|---|---|---|
| backend | Bruno e Nicolas | Scaffolding (Express, Prisma, Zod), schema e migração, models, DTOs, controllers e rotas, upload de fotos, deploy no Render. Middleware de chave de API do terminal, rotas do QR rotativo e do status, núcleo de decisão de acesso com rotas `/access/nfc` e `/access/face`, e ambiente de teste com PostgreSQL |
| mobile-readings | Nicolas | App em camadas, tela de configuração com armazenamento seguro, cliente HTTP com retry e negação por padrão, máquina de estados e repouso, presença por MQTT com fallback, QR rotativo de 10 s, leitura de NFC com bloqueio de leituras repetidas, telas de resultado, embeddings faciais em memória e 11 testes automatizados |
| frontend | Pedro | Base em React, TypeScript e Vite, cliente HTTP único, usuários (lista, criação, edição, detalhe com foto), vínculo de tags, locais e terminais, autorizações (lista, criação, cancelamento) e histórico de acessos com filtros |
| mobile-user | Bruno | Projeto Flutter, telas iniciais, integração com as rotas do backend, provider de login e primeira versão do APK |
| mobile-registry | Ryan | Projeto Flutter em camadas, tela de configuração, cliente HTTP único com retry e tratamento de 401, acessibilidade e testes unitários, de widget e de integração |
| device-esp32 | Bruna | Protótipo virtual no Tinkercad (Arduino Uno): componentes, circuito, leitura de distância com limite de 50 cm, confirmação de presença em 3 s, simulação dos comandos L e N, servo, LEDs e buzzer. Em andamento: adaptações elétricas para o ESP32, documentação com ESP32 e RC522 e lista de componentes |
| Scrum e documentação | Suelen e Bruno | Papéis e cerimônias, DoR e DoD, quadro e refinamento, registro de riscos, pauta do professor, arquitetura, README, backlog com 170 histórias, visão geral e roteiro da review |

## 4. Onde está o código

Situação verificada no GitHub em 25/10/2026.

| Serviço | Situação no repositório |
|---|---|
| backend | Na `main` |
| frontend | Na `main` (PR #5) |
| mobile-readings | Na `main` (PR #6) |
| mobile-user | Na branch `mobile-user/app-acesso`, com 6 commits à frente da `main` (login, rotas de QR e primeiro APK) |
| mobile-registry | Na branch `feat/registry-comeco`, com 2 commits à frente da `main` |
| device-esp32 | Protótipo virtual no Tinkercad (imagem em `docs/`). A pasta do firmware só tem o README |

## 5. Pull Requests da sprint

| PR | Título | Autor | Mesclado em |
|---|---|---|---|
| #1 | Papéis, DoR e DoD, riscos, pauta e Sprint 1 | Suelen | 11/10 |
| #2 | README raiz | Suelen | 11/10 |
| #3 | Documentação de arquitetura | Suelen | 21/10 |
| #4 | Leitor NFC no ESP32 e ajustes de Scrum, backlog e visão geral | Suelen | 21/10 |
| #5 | Base do frontend em React | Pedro | 21/10 |
| #6 | Implementação inicial do mobile-readings e rotas do backend | Nicolas | 21/10 |
| #7 | Develop → approval, "Tudo que realizamos na Sprint 1" (23 commits, 198 arquivos) | Helloworld-fatec | 21/10 |
| #8 | Approval → main | Helloworld-fatec | 21/10 |
| #9 | Imagem do circuito no Tinkercad | Bruna | 21/10 |

## 6. Sprint Review

- **Data e hora:** 21/10/2026, 19h30.
- **Formato:** apresentação de slides, com roteiro e tempo por bloco. Os assuntos foram o produto, a arquitetura, o código, o protótipo de hardware, as entregas e o que se espera das próximas sprints.

### 6.1 Feedback do professor

Anotações do professor e esclarecimentos do grupo, registrados como foram ditos.

| Anotação do professor | Esclarecimento do grupo |
|---|---|
| Sensor infravermelho | O professor disse que é melhor **trocar** o sensor atual (HC-SR04, ultrassônico) |
| Importante colocar o GPS | |
| Fazer uma configuração de teste: localização configurada | |
| Registrar no terminal a localização | A localização é **guardada no ESP32** |
| Display | O professor gostaria de um display |
| QR Code: adaptação | Adaptar o QR Code para que ele apareça, por exemplo, no celular ou afins |
| Bluetooth direto para o terminal, via aplicativo | Em vez do HTTP, gerar o QR Code |
| QR Code no celular: simular por meio de aplicativos | |

### 6.2 Impactos e ações propostas para a Sprint 2

Proposta da Scrum Master, **a validar com o Product Owner e com o professor**.

| Feedback | Impacto provável | Serviço (responsável) | Ação proposta |
|---|---|---|---|
| Trocar o sensor por infravermelho | O protótipo e a lista de componentes usam o HC-SR04 | device-esp32 (Bruna) | Refazer o protótipo e a lista de componentes com o sensor infravermelho |
| GPS no terminal | O RF11 pede receptor de GPS, hoje marcado como pendente | device-esp32 (Bruna) | Incluir o módulo de GPS no plano de montagem e nos componentes |
| Localização de teste configurada | O GPS tem pouco sinal em ambiente fechado | device-esp32 (Bruna) | Coordenada de teste configurável no firmware |
| Localização guardada no ESP32 | Hoje o plano guarda a coordenada do terminal no backend | device-esp32 e backend (Bruna, Bruno) | Definir como o backend passa a obter a coordenada do terminal |
| Display | O RF11 lista a tela como parte do terminal | device-esp32 e mobile-readings (Bruna, Nicolas) | Definir onde fica o display e o que ele mostra |
| QR Code no celular, por aplicativos | O QR deve poder aparecer fora do app do terminal | mobile-readings e backend (Nicolas, Bruno) | Adaptar a exibição do QR e prever a simulação por aplicativos na demonstração |
| Bluetooth no lugar do HTTP | Muda como o QR e o acesso chegam ao terminal | backend, mobile-user e device-esp32 (Bruno, Bruna) | Avaliar o canal Bluetooth entre o app do usuário e o terminal, e atualizar a arquitetura |

### 6.3 Dúvidas em aberto

1. O display é físico, no ESP32, ou é a tela do celular ou do app do terminal?
2. Quem gera o QR Code: o terminal (ESP32) ou o backend, como hoje?
3. O Bluetooth substitui o HTTP entre o app do usuário e o terminal? As regras de autorização continuam no backend?
4. O GPS será um módulo real com coordenada de teste, ou apenas uma coordenada configurada?
5. O sensor infravermelho é de obstáculo ou de presença (PIR)?

## 7. Pontos de alinhamento técnico

Diferenças entre o que está no código e o que a arquitetura define ([`docs/arquitetura.md`](../../docs/arquitetura.md)).

1. **NFC no app do terminal.** O mobile-readings (PR #6) lê NFC e o backend tem `POST /access/nfc`. A arquitetura define que a leitura é feita pelo ESP32, por MQTT (`terminal/{id}/nfc`), e que o terminal não usa NFC.
2. **Vínculo de tags no frontend.** O frontend vincula a tag por UID digitado ou por leitor USB. A arquitetura prevê o pedido de gravação (`POST /users/{id}/tags`), com o ESP32 gravando um código gerado pelo backend.
3. **Branches.** As branches `develop` e `approval` não aparecem mais no GitHub após os merges de 21/10, e a documentação ainda as cita (arquitetura, seção 8). É preciso confirmar o fluxo de branches e atualizar o texto.

## 8. Pendências que passam para a Sprint 2

| Responsável | Pendência | Pontos |
|---|---|---|
| Pedro | Login das rotas protegidas do frontend (em andamento) | 8 |
| Bruna | Adaptações elétricas para o ESP32 (em andamento) | 9 |
| Bruna | Documentar a arquitetura com ESP32 e RC522 (em andamento) | 8 |
| Bruna | Consolidar a lista de componentes físicos (em andamento) | 7 |
| Bruna | Preparar a demonstração para a Review (a fazer; a review já ocorreu, encerrar a tarefa) | 8 |
| Bruno e Ryan | Abrir PR para levar o mobile-user e o mobile-registry à `main` | |

## 9. Retrospectiva

### 9.1 Registro do time

Itens apontados pelo time na retrospectiva, cada um com o contexto que o sustenta.

**O que deu certo**

| Item do time | Contexto |
|---|---|
| Arquitetura do projeto | A arquitetura está documentada em [`docs/arquitetura.md`](../../docs/arquitetura.md), com diagrama, fluxos, tópicos MQTT e modelo de dados. Os serviços são separados e as decisões (NFC no ESP32, facial como extra, entrega local com Docker) ficaram registradas |
| Organização | Papéis e cerimônias definidos, DoR e DoD, planilha com 90 tarefas e pontuação, Pull Requests, branches protegidas e documentação do Scrum em dia |
| Extra do reconhecimento facial | O facial foi tratado como funcionalidade extra, sem atrasar o essencial, e já tem base no mobile-readings: sincronização dos embeddings em memória e cálculo de similaridade |

**O que melhorar**

| Item do time | Contexto |
|---|---|
| Os pontos que o professor disse | O feedback da review (sensor infravermelho, GPS, localização de teste guardada no ESP32, display, QR Code no celular e Bluetooth no lugar do HTTP) está na seção 6 e vira trabalho da Sprint 2 |
| Otimizar o tempo | Boa parte da integração ficou para o fim: cinco PRs entraram na `main` no dia da review, e as decisões de arquitetura vieram depois de parte do código escrito. Também restaram 5 tarefas (40 pontos) abertas |

### 9.2 Ações de melhoria para a Sprint 2

Proposta da Scrum Master a partir do registro do time, **a validar** na próxima retrospectiva.

| Item | Ação | Como acompanhar |
|---|---|---|
| Pontos do professor | Transformar cada ponto da seção 6.2 em tarefas na planilha e no quadro, cada uma com responsável | Tarefas criadas no planning da Sprint 2 |
| Otimizar o tempo | Abrir PRs menores durante a sprint, em vez de um PR grande no fim | PRs mesclados até 48 horas antes da review |
| Otimizar o tempo | Registrar a decisão de arquitetura antes de implementar | Decisão na pauta ou no backlog antes de a tarefa começar |
| Otimizar o tempo | Ensaiar a apresentação e manter a `main` estável na véspera da review | Ensaio feito e `main` sem PR pendente |
| Otimizar o tempo | Atualizar etapa e data na planilha a cada daily | Planilha atualizada nas quartas |

## 10. Próximos passos

1. Fazer o planning da Sprint 2 (Review em 11/11/2026, 19h30), incluindo o feedback do professor.
2. Levar as dúvidas da seção 6.3 ao professor e registrar as respostas em [`PAUTA-PROFESSOR.md`](../PAUTA-PROFESSOR.md).
3. Resolver os pontos de alinhamento da seção 7.
4. Mesclar o mobile-user e o mobile-registry na `main`.
5. Atualizar `docs/arquitetura.md` e o backlog conforme as respostas do professor.
6. Validar as ações de melhoria da seção 9.2 no planning da Sprint 2.
