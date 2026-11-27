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

### 6.2 Impactos para a Sprint 2 e o que foi feito

Cada ponto do feedback virou trabalho na Sprint 2. A última coluna registra o que existe hoje, conforme o código, a planilha e a documentação do hardware (posição de 22/11/2026).

| Feedback | Impacto | Serviço (responsável) | O que foi feito |
|---|---|---|---|
| Trocar o sensor por infravermelho | O protótipo e a lista de componentes usavam o HC-SR04 | device-esp32 (Bruna) | Sensor infravermelho testado em substituição ao ultrassônico, com a presença confirmada por três segundos no sensor físico |
| GPS no terminal | O RF11 pede receptor de GPS | device-esp32 (Bruna) | Módulo GY-NEO6MV2 previsto. O GPS físico ainda não foi testado e passa para a Sprint 3 |
| Localização de teste configurada | O GPS tem pouco sinal em ambiente fechado | device-esp32 (Bruna) | Coordenadas fixas de demonstração no código da simulação (comando `G`) |
| Localização guardada no ESP32 | O plano guardava a coordenada do terminal no backend | device-esp32 e backend (Bruna, Bruno) | Sem decisão registrada. O backend guarda a latitude e a longitude de cada terminal |
| Display | O RF11 lista a tela como parte do terminal | device-esp32 e mobile-readings (Bruna, Nicolas) | Display OLED no ESP32, com mensagens e QR Code testados fisicamente |
| QR Code no celular, por aplicativos | O QR deve poder aparecer fora do app do terminal | mobile-readings e backend (Nicolas, Bruno) | QR exibido no OLED e no mobile-readings. O QR do OLED foi decodificado por fotografia, e a leitura direta pelo celular está em ajuste |
| Bluetooth no lugar do HTTP | Mudaria como o QR e o acesso chegam ao terminal | backend, mobile-user e device-esp32 (Bruno, Bruna) | Sem decisão registrada. O app do usuário continua usando HTTP |

### 6.3 Dúvidas levantadas e como ficaram

| Dúvida | Como ficou | Fonte |
|---|---|---|
| O display é físico, no ESP32, ou é a tela do celular ou do app do terminal? | Display físico, um OLED no ESP32 | [`device-esp32/hardware/README.md`](../../device-esp32/hardware/README.md) |
| Quem gera o QR Code: o terminal (ESP32) ou o backend? | O backend gera e o terminal exibe | [`docs/api.md`](../../docs/api.md) |
| O Bluetooth substitui o HTTP entre o app do usuário e o terminal? | Sem decisão registrada. O HTTP segue, e as regras de autorização continuam no backend | código do `mobile-user` |
| O GPS será um módulo real com coordenada de teste, ou só uma coordenada configurada? | Hoje só coordenada fixa de demonstração. O módulo físico será testado na Sprint 3 | [`device-esp32/hardware/README.md`](../../device-esp32/hardware/README.md) |
| O sensor infravermelho é de obstáculo ou de presença (PIR)? | Sensor de obstáculos reflexivo infravermelho | [`device-esp32/hardware/README.md`](../../device-esp32/hardware/README.md) |

## 7. Pontos de alinhamento técnico

Diferenças entre o que estava no código e o que a arquitetura define ([`docs/arquitetura.md`](../../docs/arquitetura.md)), com a situação em 22/11/2026.

| # | Ponto | Situação |
|---|---|---|
| 1 | **NFC no app do terminal.** O mobile-readings (PR #6) lia NFC e o backend tem `POST /access/nfc`. A arquitetura define que a leitura é feita pelo ESP32, e que o terminal não usa NFC | Resolvido na `develop` em 20/11, com a remoção da leitura de NFC nativo do mobile-readings. Ainda não está na `main` |
| 2 | **Vínculo de tags no frontend.** O frontend vincula a tag por UID digitado ou por leitor USB. A arquitetura prevê o pedido de gravação, com o ESP32 gravando um código gerado pelo backend | Aberto. O fluxo "Gravar tag" do mobile-registry está em andamento, e o backend ainda não tem a consulta de tags do usuário |
| 3 | **Branches.** As branches `develop` e `approval` não apareciam no GitHub após os merges de 21/10, e a documentação ainda as citava | A `develop` voltou a ser a branch de integração do código. O fluxo está em [`CONTRIBUTING.md`](../../CONTRIBUTING.md) |

## 8. Pendências que passaram para a Sprint 2

| Responsável | Pendência | Pontos | Situação na planilha de 10/11 |
|---|---|---|---|
| Pedro | Login das rotas protegidas do frontend (em andamento) | 8 | Concluída |
| Bruna | Adaptações elétricas para o ESP32 (em andamento) | 9 | Concluída |
| Bruna | Documentar a arquitetura com ESP32 e RC522 (em andamento) | 8 | Concluída |
| Bruna | Consolidar a lista de componentes físicos (em andamento) | 7 | Concluída |
| Bruna | Preparar a demonstração para a Review (a fazer; a review já havia ocorrido) | 8 | Não consta mais na planilha |
| Bruno e Ryan | Abrir PR para levar o mobile-user e o mobile-registry à `main` | | Feito: mobile-user no PR #14 e mobile-registry no PR #23, levados à `main` no PR #25 |

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

### 9.2 Ações de melhoria combinadas para a Sprint 2 e o que aconteceu

As ações saíram do registro do time. A coluna da direita foi preenchida depois da Sprint 2, com fatos do repositório e da planilha.

| Item | Ação | Como acompanhar | O que aconteceu |
|---|---|---|---|
| Pontos do professor | Transformar cada ponto da seção 6.2 em tarefas na planilha e no quadro, cada uma com responsável | Tarefas criadas no planning da Sprint 2 | Atendida. As tarefas do infravermelho, do OLED e do QR estão na planilha da Bruna |
| Otimizar o tempo | Abrir PRs menores durante a sprint, em vez de um PR grande no fim | PRs mesclados até 48 horas antes da review | Não atendida. Os PRs #22, #23, #24 e #25 entraram entre 19h24 e 19h27 do dia da review (ver [`sprint-2.md`](./sprint-2.md), seção 8.1) |
| Otimizar o tempo | Registrar a decisão de arquitetura antes de implementar | Decisão na pauta ou no backlog antes de a tarefa começar | Sem registro. A divergência entre a arquitetura e o contrato MQTT segue aberta |
| Otimizar o tempo | Ensaiar a apresentação e manter a `main` estável na véspera da review | Ensaio feito e `main` sem PR pendente | Parcial. A `main` recebeu o PR #25 às 19h27 do dia da review |
| Otimizar o tempo | Atualizar etapa e data na planilha a cada daily | Planilha atualizada nas quartas | Parcial. A planilha foi atualizada, mas as abas da Alicia e da Suelen ficaram sem tarefas da Sprint 2. O time decidiu passar para o Notion |

## 10. Encaminhamentos da Sprint 1 e situação

| # | Encaminhamento | Situação em 22/11/2026 |
|---|---|---|
| 1 | Planning da Sprint 2 (Review em 11/11/2026), incluindo o feedback do professor | Feito. Os pontos da seção 6.2 viraram tarefas |
| 2 | Levar as dúvidas da seção 6.3 ao professor e registrar as respostas em [`PAUTA-PROFESSOR.md`](../PAUTA-PROFESSOR.md) | Parcial. As dúvidas da seção 6.3 foram respondidas pela implementação. A pauta foi atualizada em 22/11 |
| 3 | Resolver os pontos de alinhamento da seção 7 | Um resolvido na `develop`, um aberto e um documentado |
| 4 | Mesclar o mobile-user e o mobile-registry na `main` | Feito (seção 8) |
| 5 | Atualizar `docs/arquitetura.md` e o backlog conforme as respostas do professor | Pendente. O `arquitetura.md` não é alterado desde 18/10 |
| 6 | Validar as ações de melhoria da seção 9.2 | Feito na retrospectiva da Sprint 2 ([`sprint-2.md`](./sprint-2.md), seção 8) |
