# Estado do backlog

Situação de cada história do [`BACKLOG.md`](./BACKLOG.md), montada a partir das tarefas do Notion (banco "Backlog do Projeto"), na exportação de **22/11/2026, 17h39**. O backlog em si não muda: o `BACKLOG.md` guarda a descrição e os critérios de aceite de cada história, e este arquivo mostra o que já foi feito.

## Como ler

- Cada tarefa do Notion foi ligada à sua história pelo serviço e pelo número da US informados na planilha das Sprints 1 e 2.
- **Concluída:** todas as tarefas ligadas à história estão na etapa "Concluída". Isso não garante que todos os critérios de aceite da história foram verificados.
- **Em andamento:** a história tem tarefa concluída ou em andamento, e ainda restam tarefas.
- **Planejada:** a história só tem tarefas em "Backlog" ou "A fazer".
- **Sem tarefa:** a história não tem nenhuma tarefa no Notion. Não significa que o trabalho não foi feito, só que não foi registrado como tarefa.
- As tarefas da Sprint 3 ainda estão em "Backlog" no Notion, embora parte do código já esteja na `develop`. Por isso as histórias da Sprint 3 aparecem como planejadas até o Notion ser atualizado.

## Resumo por épico

| Épico | Serviço | Histórias | Concluídas | Em andamento | Planejadas | Sem tarefa |
|---|---|---|---|---|---|---|
| 1 | mobile-registry | 22 | 14 | 0 | 0 | 8 |
| 2 | mobile-readings | 21 | 13 | 3 | 4 | 1 |
| 3 | mobile-user | 21 | 0 | 0 | 0 | 21 |
| 4 | device-esp32 | 25 | 9 | 1 | 0 | 15 |
| 5 | backend | 21 | 6 | 0 | 0 | 15 |
| 6 | frontend | 20 | 18 | 0 | 0 | 2 |
| 7 | DevOps | 20 | 0 | 0 | 0 | 20 |
| 8 | docs/SCRUM | 20 | 11 | 1 | 0 | 8 |

## Detalhe por épico

### Épico 1: mobile-registry

| História | Título | Tarefas concluídas | Situação |
|---|---|---|---|
| US-01 | Estrutura base do aplicativo | 5 de 5 | Concluída |
| US-02 | Tela de configuração do aplicativo | 5 de 5 | Concluída |
| US-03 | Cliente HTTP único com tratamento de erros e retry | 5 de 5 | Concluída |
| US-04 | Login do administrador | 5 de 5 | Concluída |
| US-05 | Expiração de sessão e logout | 3 de 3 | Concluída |
| US-06 | Listagem de usuários com busca e filtro | 5 de 5 | Concluída |
| US-07 | Cadastro de usuário em assistente por etapas | 5 de 5 | Concluída |
| US-08 | Etapa de dados do usuário | 3 de 3 | Concluída |
| US-09 | Edição de usuário | 3 de 3 | Concluída |
| US-10 | Desativação e reativação de usuário | 3 de 3 | Concluída |
| US-11 | Solicitação de gravação de tag NFC | 5 de 5 | Concluída |
| US-12 | Situação, revogação e substituição de tag NFC | 4 de 4 | Concluída |
| US-21 | Interface acessível e simples | 5 de 5 | Concluída |
| US-22 | Testes automatizados do aplicativo | 4 de 4 | Concluída |

Histórias sem tarefa no Notion: US-13, US-14, US-15, US-16, US-17, US-18, US-19, US-20.

### Épico 2: mobile-readings

| História | Título | Tarefas concluídas | Situação |
|---|---|---|---|
| US-01 | Estrutura base do aplicativo | 1 de 1 | Concluída |
| US-02 | Tela de configuração do terminal | 1 de 1 | Concluída |
| US-04 | Máquina de estados do terminal | 1 de 1 | Concluída |
| US-05 | Assinatura do evento de presença via MQTT | 2 de 2 | Concluída |
| US-06 | Fallback de presença por polling | 2 de 2 | Concluída |
| US-07 | Exibição do QR Code rotativo | 2 de 2 | Concluída |
| US-08 | QR Code indisponível em falha de conexão | 1 de 1 | Concluída |
| US-09 | Resultado do acesso por tag NFC | 1 de 1 | Concluída |
| US-10 | Aviso de leitor ocupado na gravação de tag | 1 de 2 | Em andamento |
| US-11 | Feedback visual do resultado do acesso | 2 de 2 | Concluída |
| US-12 | Comportamento seguro sem conexão com o backend | 1 de 1 | Concluída |
| US-13 | Modo de repouso e economia de energia | 1 de 1 | Concluída |
| US-14 | Execução como terminal dedicado | 0 de 1 | Planejada |
| US-15 | Sincronização dos embeddings faciais | 1 de 1 | Concluída |
| US-16 | Detecção de rosto na câmera | 0 de 1 | Planejada |
| US-17 | Reconhecimento facial local | 1 de 2 | Em andamento |
| US-18 | Envio do resultado da identificação facial | 0 de 1 | Planejada |
| US-19 | Calibração e limitações do reconhecimento facial | 0 de 1 | Planejada |
| US-20 | Interface simples e acessível | 1 de 2 | Em andamento |
| US-21 | Testes automatizados do aplicativo | 2 de 2 | Concluída |

Histórias sem tarefa no Notion: US-03.

### Épico 3: mobile-user

Histórias sem tarefa no Notion: US-01, US-02, US-03, US-04, US-05, US-06, US-07, US-08, US-09, US-10, US-11, US-12, US-13, US-14, US-15, US-16, US-17, US-18, US-19, US-20, US-21.

### Épico 4: device-esp32

| História | Título | Tarefas concluídas | Situação |
|---|---|---|---|
| US-02 | Configuração e gestão de segredos do firmware | 1 de 1 | Concluída |
| US-03 | Montagem do hardware e proteções elétricas | 9 de 10 | Em andamento |
| US-06 | Leitura e filtragem do sensor HC-SR04 | 2 de 2 | Concluída |
| US-07 | Detecção e publicação de presença | 3 de 3 | Concluída |
| US-08 | Recebimento e validação de comandos | 1 de 1 | Concluída |
| US-09 | Acionamento da trava eletrônica | 1 de 1 | Concluída |
| US-10 | Negação do acesso | 1 de 1 | Concluída |
| US-11 | Buzzer e LED não bloqueantes | 1 de 1 | Concluída |
| US-13 | Máquina de estados do dispositivo | 2 de 2 | Concluída |
| US-21 | Testes do firmware | 3 de 3 | Concluída |

Histórias sem tarefa no Notion: US-01, US-04, US-05, US-12, US-14, US-15, US-16, US-17, US-18, US-19, US-20, US-22, US-23, US-24, US-25.

### Épico 5: backend

| História | Título | Tarefas concluídas | Situação |
|---|---|---|---|
| US-09 | Autenticação dos terminais | 1 de 1 | Concluída |
| US-11 | Geração do QR Code rotativo | 1 de 1 | Concluída |
| US-12 | Núcleo de decisão de acesso e validação por NFC | 3 de 3 | Concluída |
| US-14 | Validação de acesso por reconhecimento facial | 1 de 1 | Concluída |
| US-16 | Presença e estado dos terminais | 2 de 2 | Concluída |
| US-21 | Testes automatizados do backend | 1 de 1 | Concluída |

Histórias sem tarefa no Notion: US-01, US-02, US-03, US-04, US-05, US-06, US-07, US-08, US-10, US-13, US-15, US-17, US-18, US-19, US-20.

### Épico 6: frontend

| História | Título | Tarefas concluídas | Situação |
|---|---|---|---|
| US-01 | Estrutura base do frontend | 3 de 3 | Concluída |
| US-02 | Cliente HTTP único | 1 de 1 | Concluída |
| US-03 | Login do administrador e proteção de rotas | 2 de 2 | Concluída |
| US-04 | Lista de usuários | 1 de 1 | Concluída |
| US-05 | Cadastro, edição e desativação de usuários | 1 de 1 | Concluída |
| US-06 | Detalhe do usuário | 1 de 1 | Concluída |
| US-07 | Pedido de gravação de tag NFC pelo navegador | 1 de 1 | Concluída |
| US-09 | Cadastro de locais e terminais | 1 de 1 | Concluída |
| US-10 | Lista de autorizações com filtros | 1 de 1 | Concluída |
| US-11 | Criação de autorização | 2 de 2 | Concluída |
| US-12 | Cancelamento de autorização | 1 de 1 | Concluída |
| US-13 | Histórico de acessos | 1 de 1 | Concluída |
| US-15 | Dashboard: indicadores | 4 de 4 | Concluída |
| US-16 | Dashboard: monitoramento em tempo quase real | 3 de 3 | Concluída |
| US-17 | Configuração independente do endereço do servidor | 2 de 2 | Concluída |
| US-18 | Usabilidade e acessibilidade | 2 de 2 | Concluída |
| US-19 | Segurança e privacidade no frontend | 2 de 2 | Concluída |
| US-20 | Testes automatizados do frontend | 3 de 3 | Concluída |

Histórias sem tarefa no Notion: US-08, US-14.

### Épico 7: DevOps

Histórias sem tarefa no Notion: US-01, US-02, US-03, US-04, US-05, US-06, US-07, US-08, US-09, US-10, US-11, US-12, US-13, US-14, US-15, US-16, US-17, US-18, US-19, US-20.

### Épico 8: docs/SCRUM

| História | Título | Tarefas concluídas | Situação |
|---|---|---|---|
| US-01 | Papéis e cerimônias do Scrum | 3 de 3 | Concluída |
| US-02 | Refinamento e priorização do backlog | 1 de 1 | Concluída |
| US-03 | Definition of Ready e Definition of Done | 1 de 1 | Concluída |
| US-04 | Planejamento de sprint | 2 de 2 | Concluída |
| US-05 | Quadro de tarefas e rastreabilidade | 2 de 2 | Concluída |
| US-06 | Acompanhamento do progresso | 1 de 1 | Concluída |
| US-07 | Sprint Review e entregas parciais | 2 de 3 | Em andamento |
| US-09 | Registro de riscos e decisões em aberto | 1 de 1 | Concluída |
| US-10 | Esclarecimento de requisitos com o professor | 3 de 3 | Concluída |
| US-11 | Documentação da arquitetura | 2 de 2 | Concluída |
| US-12 | Diagramas de casos de uso | 1 de 1 | Concluída |
| US-18 | README e manual de instalação e execução | 1 de 1 | Concluída |

Histórias sem tarefa no Notion: US-08, US-13, US-14, US-15, US-16, US-17, US-19, US-20.

## Tarefas sem história

30 tarefas do Notion não têm número de história na planilha (a maior parte são tarefas do Bruno no backend e no mobile-user, e os modelos de planejamento da Sprint 3) e por isso não entram nas tabelas acima:

| Tarefa | Responsável | Etapa |
|---|---|---|
| Testar a comunicação e a leitura do módulo GPS | Bruna Rodrigues | Backlog |
| criar repositório do projeto e estruturas de pasta | Bruno Berval | Concluída |
| fazer scaffolding do backend | Bruno Berval | Concluída |
| criar primeiro schema prisma | Bruno Berval | Concluída |
| criar Backlog do projeto | Bruno Berval | Concluída |
| criar os models e dtos | Bruno Berval | Concluída |
| criar controllers e routes | Bruno Berval | Concluída |
| configurar middleware de upload de fotos | Bruno Berval | Concluída |
| fazer deploy da primeira versao do backend para facilitar o desenvolvimento | Bruno Berval | Concluída |
| fazer scaffolding do projeto flutter | Bruno Berval | Concluída |
| criação das primeiras telas e definição do design | Bruno Berval | Concluída |
| integracao da rotas do backend com o app mobile | Bruno Berval | Concluída |
| criaçao do provider de login | Bruno Berval | Concluída |
| build da primeira versao do apk | Bruno Berval | Concluída |
| criar rotas de autenticação | Bruno Berval | Concluída |
| criar rotas de criação de qr code para exbição no device do arduino | Bruno Berval | Concluída |
| criar middleware de autenticação | Bruno Berval | Concluída |
| criar o "contrato" de comunicação entre os serviços | Bruno Berval | Concluída |
| ajuste estilização do app de usuarios | Bruno Berval | Concluída |
| Testes de integração E2E e ensaio da demonstração final | Nicolas Kauê | Backlog |
| Testar e corrigir firmware, comunicação e acionamento do ESP32 | Bruna Rodrigues | Backlog |
| Corrigir falhas de backend/frontend e apoiar testes de build e integração | Pedro Enrique | Backlog |
| Consolidar documentação geral e roteiro da demonstração | Suelen Castro | Backlog |
| Validar entregas, critérios de aceite e prioridades finais | Bruno Berval | Backlog |
| Testar e corrigir leituras móveis QR Code e NFC | Nicolas Kauê | Backlog |
| Configurar e documentar pipeline CI/CD | Suelen Castro | Backlog |
| Preparar Docker Compose para execução local dos serviços | Pedro Enrique | Backlog |
| Implementar testes automatizados do backend para autorização e logs | Pedro Enrique | Backlog |
| Executar testes ponta a ponta, registrar evidências e atualizar documentação técnica | Alicia | Backlog |
| Testar e corrigir registro móvel e histórico de acessos | Ryan Tinel | Backlog |
