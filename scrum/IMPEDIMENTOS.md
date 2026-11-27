# Registro de impedimentos

Impedimento é o que trava uma tarefa e precisa de alguém de fora dela para destravar. Este registro reúne os impedimentos apontados nas reviews, nas dailies e na leitura do repositório, com quem cuida de cada um e como terminou. Os riscos que ainda não aconteceram ficam em [`RISCOS.md`](./RISCOS.md).

Situação em 23/11/2026. Fontes: seções de impedimentos e retrospectiva de cada sprint em [`sprints/`](./sprints/) e histórico do GitHub.

## Sprint 1 (30/09 a 21/10)

| # | Impedimento | Quem | Situação | Como terminou |
|---|---|---|---|---|
| 1 | Login das rotas protegidas do frontend não terminou na sprint | Pedro | Resolvido | Concluído na Sprint 2 ([`sprint-1.md`](./sprints/sprint-1.md), seção 8) |
| 2 | Tarefas do device-esp32 em andamento ao fim da sprint (adaptações elétricas, documentação da arquitetura com ESP32 e RC522, lista de componentes) | Bruna | Resolvido | Constam concluídas na planilha de 10/11 |
| 3 | Branches `develop` e `approval` sumiram do GitHub após os merges de 21/10 | Suelen | Resolvido | Regra registrada em [`CONTRIBUTING.md`](../CONTRIBUTING.md) |
| 4 | Leitura de NFC no app do terminal, quando o leitor passou a ser o do ESP32 | Nicolas | Resolvido | Leitura nativa retirada do mobile-readings na `develop` (20/11). Ainda não está na `main` |
| 4a | Vínculo de tags pelo frontend por UID digitado, sem o fluxo de gravação pelo ESP32 | Ryan e Bruno | Aberto | O botão "Gravar tag" do mobile-registry e a consulta de tags no backend dependem do MQTT (seção 7, item 2, de [`sprint-1.md`](./sprints/sprint-1.md)) |

## Sprint 2 (22/10 a 11/11)

| # | Impedimento | Quem | Situação | Como terminou |
|---|---|---|---|---|
| 5 | Compilação extremamente lenta do mobile-registry, que atrasa os testes | Ryan | Aberto | Relatado na Review 2. Segue acompanhado nas dailies da Sprint 3 |
| 6 | Leitor RC522 com possível falha na soldagem | Bruna | Aberto | Aguarda a avaliação do professor. Diagnóstico e integração passaram para a Sprint 3 |
| 7 | GPS do terminal ainda sem teste | Bruna | Aberto | Passou para a Sprint 3 |
| 8 | PRs #22 a #25 entraram na `main` entre 19h24 e 19h27 do dia da review | Time | Resolvido pela regra | Regra de mesclar até 48 horas antes da review, em [`CONTRIBUTING.md`](../CONTRIBUTING.md) |
| 9 | Abas da Alicia e da Suelen sem tarefas na planilha | Suelen | Resolvido | O time passou para o Notion |
| 10 | Arquitetura e contrato MQTT divergentes | Bruno, Bruna e Nicolas | Resolvido | `docs/arquitetura.md` atualizado para o contrato v1 em 22/11 |
| 11 | Diagrama de caso de uso a refazer (pedido do professor) | Alicia | Resolvido | Novo diagrama na `main` em 20/11 (PR #28) |

## Sprint 3 (11/11 a 25/11)

| # | Impedimento | Quem | Situação | Observação |
|---|---|---|---|---|
| 12 | `develop` 26 commits à frente da `main` e `feat/estrutura` 26 commits atrás da `develop`, sem mesclar | Bruno | Aberto | Ordem combinada: `feat/estrutura` na `develop`, depois `develop` na `main` (R21 em [`RISCOS.md`](./RISCOS.md)) |
| 13 | Pipeline do mobile-registry falha no passo `flutter build apk` | Ryan | Aberto | Os demais workflows estão na `feat/estrutura` (R5) |
| 14 | Duas implementações de reconhecimento facial: `face-service` na `develop` e `face-recognition` na `feat/estrutura` | Bruno e Nicolas | Aberto | Decidir qual segue antes de mesclar |
| 15 | Código do Ryan e da Bruna ainda não está no repositório | Ryan e Bruna | Aberto | Bruna trabalha no ESP32, que tem menos código que os demais serviços |
| 16 | Tarefas da Sprint 3 no Notion desatualizadas em relação ao código | Todos | Aberto | Atualizar a etapa a cada daily |

## Como usar este registro

- Quem encontra um impedimento avisa na daily. A Scrum Master registra aqui com o responsável.
- O responsável atualiza a coluna de situação. Só vira "Resolvido" com o resultado escrito na coluna ao lado.
- Na retrospectiva, os impedimentos abertos viram ações em [`sprints/`](./sprints/).
