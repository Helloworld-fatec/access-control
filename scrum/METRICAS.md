# Métricas das sprints

Números de cada sprint, com a fonte de cada um. A pontuação de cada tarefa é **4 + dificuldade + prioridade** (fórmula da planilha usada nas Sprints 1 e 2). Desde a Sprint 3 as tarefas ficam no Notion, banco "Backlog do Projeto" (decisão da retrospectiva da Sprint 2), então não há pontuação de planilha para a Sprint 3.

Situação em 23/11/2026.

## Resumo

| Sprint | Período | Fonte | Tarefas planejadas | Tarefas concluídas | Pontos planejados | Pontos concluídos |
|---|---|---|---|---|---|---|
| 1 | 30/09 a 21/10 | Planilha em 21/10 (review) | 90 | 85 (94%) | 690 | 650 (94%) |
| 2 | 22/10 a 11/11 | Planilha em 10/11 (véspera da review) | 79 | 63 (80%) | 647 | 510 (79%) |
| 2 | 22/10 a 11/11 | Notion em 22/11 | 89 | 89 (100%) | | |
| 3 | 11/11 a 25/11 | Notion em 22/11 | 20 | em andamento | | |

Leitura dos números:

- **Sprint 1.** Planilha de 90 tarefas. Cinco ficaram abertas (40 pontos), entre elas o login das rotas protegidas do frontend e itens do device-esp32. Os detalhes estão em [`sprints/sprint-1.md`](./sprints/sprint-1.md).
- **Sprint 2.** Na véspera da review, 16 tarefas estavam abertas, a maioria do Ryan (cadastro em etapas, gravar tag e situação das tags). Depois da review, o time passou para o Notion e todas as 89 tarefas da sprint constam como "Concluída" em 22/11. O RC522 e o teste do GPS foram listados pela Bruna como trabalho da Sprint 3. Os detalhes estão em [`sprints/sprint-2.md`](./sprints/sprint-2.md), seção 2.1.
- **Sprint 3.** O Notion tem 20 tarefas: 8 do Nicolas no mobile-readings, 10 linhas-modelo dos demais integrantes e as 2 que a Bruna passou da Sprint 2 (RC522 e GPS). O resultado entra aqui depois da Review 3.
- As contagens da planilha e do Notion diferem porque o Notion foi montado a partir da planilha, com a remoção de linhas duplicadas e a inclusão das tarefas da Alicia e da Suelen. Por isso o número de tarefas não é comparável sem ler a fonte.

## Por responsável

Tarefas planejadas e concluídas na planilha, pontos entre parênteses.

| Responsável | Serviço | Sprint 1 (21/10) | Sprint 2 (10/11) |
|---|---|---|---|
| Ryan | mobile-registry | 24 de 24 (180 de 180) | 22 de 36 (175 de 292) |
| Pedro | frontend | 11 de 12 (87 de 95) | 20 de 20 (165 de 165) |
| Bruna | device-esp32 | 12 de 16 (103 de 135) | 9 de 10 (82 de 92) |
| Nicolas | mobile-readings e rotas do backend | 14 de 14 (106 de 106) | 7 de 8 (54 de 64) |
| Bruno | backend, mobile-user e repositório | 13 de 13 (89 de 89) | 5 de 5 (34 de 34) |
| Suelen | Scrum e documentação | 11 de 11 (85 de 85) | sem tarefas na planilha |
| Alicia | diagrama de caso de uso e testes do backend | não fazia parte do time | sem tarefas na planilha |

Fechamento da Sprint 2 pelo Notion (22/11): Ryan 36, Pedro 20, Nicolas 8, Bruno 5, Alicia 2, Suelen 9 e Bruna 9 tarefas, todas concluídas.

## Entregas por sprint no repositório

| Sprint | Pull Requests na `main` | Outros marcos |
|---|---|---|
| 1 | PRs da primeira sprint, listados em [`sprints/sprint-1.md`](./sprints/sprint-1.md), seção 5 | Estrutura do código dos serviços, documentação do Scrum |
| 2 | PRs #10 a #25 (os #22 a #25 de 11/11), listados em [`sprints/sprint-2.md`](./sprints/sprint-2.md), seções 5 e 8.1 | Fluxos de QR Code e NFC, sensor infravermelho e display no terminal |
| 3 | PRs #26 a #28 na `main`. PRs #29 e #30 na `develop`, ainda fora da `main` | Documentação final, diagrama de caso de uso refeito, reconhecimento facial, painel e Docker Compose na `develop` |

## Observações de processo

- **Entrega na véspera.** Nas duas primeiras reviews houve PRs mesclados no próprio dia (cinco na Sprint 1 e quatro na Sprint 2, entre 19h24 e 19h27). A regra de mesclar até 48 horas antes da review entrou em [`CONTRIBUTING.md`](../CONTRIBUTING.md) e vale para a Review 3.
- **Cerimônias.** Planning na abertura de cada sprint, daily às quartas, 20h30, review às 19h30 e retrospectiva na mesma noite. Calendário em [`README.md`](./README.md).
- **Impedimentos.** O registro de todos os impedimentos está em [`IMPEDIMENTOS.md`](./IMPEDIMENTOS.md).
