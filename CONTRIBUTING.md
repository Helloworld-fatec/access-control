# Como contribuir: branches, commits e Pull Requests

Registro do fluxo de trabalho do time, escrito em 22/11/2026 a partir do que o repositório mostra desde a Sprint 1. Atende ao RNF11 do Desafio (controle de versão com branches organizadas, commits descritivos e estratégia de versionamento definida). Qualquer ajuste combinado na daily deve ser registrado aqui.

## Branches

| Branch | Para que serve |
|---|---|
| `main` | Versão estável, a que vai para a Sprint Review e para a entrega final |
| `develop` | Integração do código das funcionalidades |
| `feat/<assunto>` ou `feature/<assunto>` | Uma funcionalidade nova, por exemplo `feat/mobile-registry` |
| `fix/<assunto>` | Correção de um defeito |
| `docs/<assunto>` | Documentação e arquivos de Scrum, por exemplo `docs/sprint-2-atualiza` |

## Fluxo

1. Crie a branch a partir da `develop` (código) ou da `main` (documentação).
2. Faça commits pequenos e frequentes, com o padrão abaixo.
3. Abra um **Pull Request**, preenchendo o [template](./.github/pull_request_template.md). A base é a `develop` para código e a `main` para documentação.
4. Peça a revisão de pelo menos uma pessoa do time. Resolva os comentários antes do merge.
5. Atualize a etapa da tarefa no Notion.
6. A `develop` chega à `main` por um Pull Request próprio. Isso deve acontecer antes de cada Sprint Review e na entrega final.

**Prazo:** os Pull Requests da sprint devem ser mesclados até **48 horas antes da Sprint Review**, para a `main` ficar estável na véspera. Isso foi combinado na retrospectiva da Sprint 2 ([`sprint-2.md`](./scrum/sprints/sprint-2.md), seção 8.2).

## Commits

Mensagens curtas, em português, no formato `tipo(escopo): descrição`.

| Tipo | Quando usar |
|---|---|
| `feat` | Funcionalidade nova |
| `fix` | Correção de defeito |
| `docs` | Documentação |
| `refactor` | Reorganização do código sem mudar o comportamento |
| `perf` | Melhoria de desempenho |
| `test` | Testes |
| `build` e `chore` | Dependências, configuração e tarefas de manutenção |

Exemplos: `feat(frontend): painel integrado ao backend`, `fix(backend): restaura scripts dev, build e start`, `docs(sprint-2): registra feedback da review`.

## Pull Requests

- Um assunto por Pull Request, o menor possível.
- Siga a Definition of Done em [`scrum/DOR-DOD.md`](./scrum/DOR-DOD.md): critérios de aceite atendidos, testes passando, documentação atualizada e funcionamento demonstrável.
- Nunca versione `.env`, chaves ou senhas. Use o `.env.example` com valores de exemplo.

## Versionamento

A entrega final recebe a tag `v1.0.0` na `main`, criada pelo Bruno. Até a data desta escrita, o repositório ainda não tem tags nem releases.

## Onde ficam as tarefas

No Notion, no banco "Backlog do Projeto" ([`PAPEIS.md`](./scrum/PAPEIS.md), seção "Combinados do time"). O repositório não usa issues.
