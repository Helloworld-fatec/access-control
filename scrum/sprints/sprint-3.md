# Sprint 3

Registro da terceira sprint do projeto access-control: meta, o que passa da Sprint 2, tarefas planejadas, cerimônias e o acompanhamento durante a sprint. As tarefas de cada pessoa ficam no Notion.

| Item | Valor |
|---|---|
| Período | 11/11/2026 (depois da Review 2) a 25/11/2026 |
| Daily | quartas, 20h30 |
| Sprint Review 3 | 25/11/2026, 19h30 |
| Retrospectiva | na noite da review, logo depois dela |
| Product Owner | Bruno |
| Scrum Master | Suelen |
| Professor | Leandro Toss Hoffmann |
| Onde ficam as tarefas | Notion, banco "Backlog do Projeto" (decisão registrada na retrospectiva da Sprint 2) |

## 1. Meta da sprint

Chegar à Review 3 com os serviços integrados e a entrega final pronta para demonstração: integração do terminal com o backend, CI/CD, testes automatizados e refinamento, conforme o cronograma do [README](../../README.md). A apresentação final tem data a definir pelo professor.

## 2. O que passa da Sprint 2

| Serviço | Responsável | O que falta |
|---|---|---|
| mobile-registry | Ryan | Cadastro em etapas (US-07), gravar tag no terminal (US-11) e situação e revogação das tags (US-12) |
| mobile-readings e backend | Nicolas | Integração do fluxo de unlock com a publicação MQTT |
| device-esp32 | Bruna | Revisão e integração do RC522, testes do GPS, comunicação com o backend via MQTT, suporte físico ou maquete e ajuste do QR Code para leitura direta pelo celular |
| Diagrama de caso de uso | Alicia | Feito: o diagrama refeito conforme o feedback do professor entrou na `main` em 20/11 (PR #28, commit de 17/11) |

## 3. Tarefas já planejadas

Tarefas do Nicolas para o mobile-readings, já lançadas na planilha da Sprint 3:

| Tarefa | Critério de aceite |
|---|---|
| Exibir aviso de leitor ocupado na gravação de tag | Assinar o tópico de gravação e exibir "Leitor ocupado" na tela do terminal |
| Modo terminal dedicado (kiosk e tela cheia) | Travar a orientação da tela e manter o display sempre ativo |
| Captura da câmera frontal ao detectar presença | Ativar a câmera frontal só ao sair do repouso e enquadrar o rosto |
| Reconhecimento facial local em tempo real | Comparar o embedding facial com a lista em memória, com similaridade acima do limiar |
| Envio da validação facial para o backend | Submeter a identificação facial com o score de similaridade |
| Calibração do limiar facial e feedback de iluminação | Permitir ajuste de sensibilidade nas configurações e alertar se a luz for insuficiente |
| Acessibilidade e voz para os resultados | Emitir feedback sonoro para pessoas com deficiência visual |
| Testes de integração de ponta a ponta e ensaio da demonstração final | Validar o fluxo completo: presença, câmera, QR ou NFC, backend e abertura da trava |

Responsabilidades já definidas em [`PAPEIS.md`](../PAPEIS.md) e no Notion, ainda sem tarefas detalhadas:

| Responsável | Item |
|---|---|
| Suelen | Configurar e documentar o pipeline de CI/CD; consolidar a documentação geral e o roteiro da demonstração |
| Pedro | Docker Compose para a execução local dos serviços; testes automatizados do backend; apoio a build e integração |
| Alicia | Testes de ponta a ponta, com evidências e documentação técnica atualizada |
| Bruno | Validação das entregas e dos critérios de aceite finais, como Product Owner |
| Ryan | Testes e correções do registro móvel e do histórico de acessos |

### 3.1 Andamento em 22/11/2026

Fonte: histórico do GitHub (commits e Pull Requests). O Notion tem o detalhe de cada tarefa.

**Já na `develop`, ainda fora da `main`** (PRs #29 e #30, de 20 e 21/11):

| Serviço | Responsável | O que entrou |
|---|---|---|
| mobile-readings | Nicolas | Reconhecimento facial com microsserviço em Python e captura real da câmera, sincronização dos embeddings, terminal sem leitura de NFC nativo, tela que abre sem esperar a rede e paleta alinhada ao frontend |
| frontend | Pedro | Frontend integrado ao backend, painel, exportação do histórico em CSV, novo visual, documentação em `docs/frontend.md`, Dockerfile e Nginx |
| backend | Bruno e Pedro | Rotas do painel e da exportação do histórico, scripts `dev`, `start` e `admin:create`, Dockerfile e `docker-compose.yml` com banco, backend e frontend |

**Em branches ainda não mescladas:** a `feat/estrutura` (Bruno) tem scripts de CI/CD e containerização (17/11), reconhecimento facial e ajustes do app de registros (20 e 21/11) e a estruturação do MQTT (22/11), com 6 workflows de CI/CD. A branch está 26 commits atrás da `develop`.

**Na `main`:** o diagrama de caso de uso atualizado da Alicia (17/11) e a documentação (PRs #26, #27 e #28).

**Ainda vão subir o código:** Ryan e Bruna. A Bruna trabalha no ESP32, que tem menos código que os demais serviços. O Bruno ainda vai mesclar a `feat/estrutura` e a `develop` na `main`.

**No Notion (exportação de 22/11):** as 18 tarefas da Sprint 3 seguem em "Backlog": 8 do Nicolas e 10 linhas-modelo (Bruna, Pedro, Suelen, Bruno, Nicolas, Alicia e Ryan). Parte do código dessas tarefas, como o reconhecimento facial e o modo terminal, já está na `develop`, então o Notion precisa ser atualizado. A situação de cada história do backlog está em [`ESTADO-BACKLOG.md`](../ESTADO-BACKLOG.md).

## 4. Pendências apontadas na matriz de requisitos

A [matriz de requisitos](../../docs/matriz-requisitos.md) lista o que impede cada requisito de estar atendido. Estes itens ainda não têm responsável nem tarefa e devem ser tratados no planning:

1. **Integração do backend com o ESP32 por MQTT** (RF11, RF15). Hoje a abertura da porta é simulada no backend.
2. **Proximidade geográfica no acesso por QR** (RF13). O app precisa enviar a localização, e o backend precisa calcular a distância.
3. **Um só formato de QR**, renovado a cada 10 segundos e aceito pelo `/access/qr/consume` (RF12).
4. **Login nas rotas de usuários, locais e histórico** (RNF02).
5. **CI/CD e testes no pipeline** para backend, frontend e firmware (RNF08 a RNF10 e RNF12). Na `main` só o mobile-registry tem workflow, e os últimos runs falharam. A branch `feat/estrutura` traz 6 workflows, ainda não mesclados.
6. **Docker Compose** com banco, backend e frontend já existe na `develop` e falta chegar à `main`. O banco em nuvem (RNF06) não tem evidência no repositório.
7. **Scripts do backend:** `dev` e `start` já estão na `develop`. Falta chegar à `main`.

## 5. Ações da retrospectiva da Sprint 2

Propostas em [`sprint-2.md`](./sprint-2.md), seção 8.2:

| Ação | Responsável | Como acompanhar |
|---|---|---|
| Usar o Notion como fonte das tarefas | Suelen e cada integrante | Notion atualizado a cada daily |
| Abrir PRs menores e mesclar até 48 horas antes da review | Todos | PRs mesclados até 23/11, 19h30 |
| Refazer o diagrama de caso de uso | Alicia | Feito: novo diagrama no PR #28, mesclado em 20/11 |
| Reduzir o tempo de compilação do mobile-registry | Ryan | Relato na daily |
| Levar ao professor a avaliação do RC522 | Bruna e Suelen | Resposta registrada na daily |
| Validar o contrato MQTT e decidir entre arquitetura e contrato | Bruno, Bruna e Nicolas | Decisão registrada em `docs/` |

## 6. Dailies

Registro curto de cada daily: o que foi dito e o que ficou combinado.

| Data | Temas | Combinados |
|---|---|---|
| Depois da Review 2 | Organização das tasks e tempo | Usar o Notion no lugar da planilha |
| Durante a Sprint 3 | Impedimentos: os apresentados na Review 2 (compilação lenta do mobile-registry, RC522 e GPS) e a organização das tarefas | Entregar o projeto funcionando |
