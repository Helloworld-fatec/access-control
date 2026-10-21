# Project Backlog: access-control

**Sistema Integrado de Controle de Acesso** · ABP 2026-2 · 4º DSM · FATEC Jacareí

Legenda de prioridade (MoSCoW): **Must** (essencial), **Should** (importante), **Could** (desejável / extra).
Os identificadores `US` reiniciam em cada épico. Referências a requisitos (RF, RNF, RP) vêm do documento do desafio.

> **Atualização de 18/10/2026:** por definição do professor, a leitura de tags NFC é feita pelo ESP32, e não pelo terminal. Por definição do Product Owner, o mesmo ESP32 grava nas tags um código gerado pelo backend, a pedido do mobile-registry ou do frontend. Histórias ajustadas: épico 1 (US-11 e US-12), épico 2 (US-09 e US-10), épico 4 (novas US-22 a US-25), épico 5 (US-05, US-09, US-12 e US-15) e épico 6 (US-07). O épico 4 passa a ter 25 histórias.

---

# Épico 1: mobile-registry

**Descrição:** aplicativo Flutter de cadastro, usado pelo administrador (portaria ou administração do prédio) para criar usuários, pedir a gravação das tags NFC e registrar o rosto, aproveitando a câmera do aparelho. A tag é gravada pelo ESP32 do terminal, com um código gerado pelo backend; o app não usa o NFC do celular. É também a redundância do frontend para o cadastro básico. O app coleta e envia dados; o backend valida e decide.

**Requisitos relacionados:** RF01, RF07, RF10, RNF02, RNF03, RNF04, RNF05, RP04, RP05

---

### US-01: Estrutura base do aplicativo
**Prioridade:** Must

**Como** desenvolvedor,
**quero** um projeto Flutter organizado em camadas (telas, serviços, repositórios),
**para** facilitar a manutenção e a evolução do app (RNF05).

**Critérios de aceite:**
- Projeto Flutter criado com estrutura de pastas separando telas, estado, repositórios e serviços.
- Gerenciamento de estado definido (Riverpod ou Bloc), o mesmo padrão dos demais apps Flutter.
- Tema, navegação e tratamento global de erros configurados.
- O app compila e executa em um dispositivo Android real.

---

### US-02: Tela de configuração do aplicativo
**Prioridade:** Must

**Como** administrador,
**quero** configurar o endereço do backend, o tamanho máximo da foto e o número de amostras faciais,
**para** adaptar o app a outra rede sem precisar recompilar.

**Critérios de aceite:**
- Tela de configuração acessível antes do login.
- Campos: endereço do backend (IP e porta), tamanho máximo da foto (padrão 50 KB) e número de amostras faciais por cadastro.
- Valores persistidos em `shared_preferences` e aplicados imediatamente ao cliente HTTP.
- Validação do formato de IP e porta, com mensagem de erro clara.
- Android configurado com `usesCleartextTraffic` para HTTP na LAN, e permissão de câmera declarada.

---

### US-03: Cliente HTTP único com tratamento de erros e retry
**Prioridade:** Must

**Como** administrador,
**quero** que o app tente novamente chamadas que falharam por instabilidade de rede e me explique o problema,
**para** não perder o cadastro por uma falha temporária (RNF03).

**Critérios de aceite:**
- Uma única camada de acesso à API, com tratamento central do token e dos erros.
- Retry automático em falhas de rede e de timeout, com limite de tentativas.
- Mensagens claras e em linguagem simples para falha de rede, erro do servidor e conflito.
- Em resposta 401, o app encerra a sessão e leva o usuário ao login.
- O app se comunica exclusivamente com o backend (RP05).

---

### US-04: Login do administrador
**Prioridade:** Must

**Como** administrador,
**quero** entrar no aplicativo com usuário e senha,
**para** acessar as funções de cadastro de forma segura (RF07).

**Critérios de aceite:**
- Tela de login com usuário e senha, com opção de mostrar a senha.
- Autenticação por `POST /auth/login`, que devolve o token de acesso.
- Token guardado em `flutter_secure_storage`, nunca em `shared_preferences`.
- Apenas o perfil de administrador acessa o app: condôminos e visitantes recebem acesso negado.
- Se já houver sessão válida, o app abre direto na lista de usuários.

---

### US-05: Expiração de sessão e logout
**Prioridade:** Must

**Como** administrador,
**quero** que a sessão expire e que eu possa sair do app,
**para** impedir o uso indevido do aparelho (RNF02).

**Critérios de aceite:**
- Ao vencer o token, o app exige novo login e informa o motivo.
- Botão de sair limpa o token do armazenamento seguro.
- Nenhuma tela protegida fica acessível após o logout, nem pelo botão de voltar.

---

### US-06: Listagem de usuários com busca e filtro
**Prioridade:** Must

**Como** administrador,
**quero** listar usuários, buscando por nome ou documento e filtrando por perfil,
**para** encontrar rapidamente quem preciso editar ou cadastrar (RF01).

**Critérios de aceite:**
- Lista obtida por `GET /users`, com paginação.
- Busca por nome ou documento.
- Filtro por perfil: administrador, condômino ou visitante.
- Cada item indica perfil, situação (ativo ou inativo) e se há tag NFC ativa e rosto vinculados.
- Estados de carregamento, lista vazia e erro tratados.

---

### US-07: Cadastro de usuário em assistente por etapas
**Prioridade:** Must

**Como** administrador,
**quero** cadastrar um usuário em um assistente por etapas,
**para** concluir o cadastro de forma simples e sem me perder (RF01, RNF04).

**Critérios de aceite:**
- Etapas: 1) dados do usuário, 2) gravação da tag NFC (opcional), 3) rosto (opcional), 4) revisão.
- Indicador de progresso visível e botões de avançar e voltar.
- As etapas 2 e 3 podem ser puladas e feitas depois, pela tela de edição.
- Na revisão, o administrador confere todos os dados antes de confirmar.
- O usuário é enviado primeiro (`POST /users`) e os vínculos em seguida, para não perder o cadastro inteiro se uma etapa falhar.

---

### US-08: Etapa de dados do usuário
**Prioridade:** Must

**Como** administrador,
**quero** informar nome, documento, e-mail ou telefone, perfil e credenciais de login,
**para** criar o usuário com os perfis previstos (RF01).

**Critérios de aceite:**
- Campos: nome, documento, e-mail ou telefone, perfil (administrador, condômino ou visitante), usuário e senha.
- Validação básica no app (campos obrigatórios e formato de e-mail), com validação definitiva no backend.
- Erros do backend (por exemplo, documento duplicado) exibidos de forma clara no campo correspondente.
- O app não valida regras de negócio por conta própria, como unicidade de tag ou documento.

---

### US-09: Edição de usuário
**Prioridade:** Must

**Como** administrador,
**quero** editar os dados de um usuário já cadastrado,
**para** corrigir informações e completar as etapas opcionais depois.

**Critérios de aceite:**
- Tela de detalhe e edição com os dados atuais, enviada por `PUT /users/{id}`.
- A partir dessa tela é possível pedir a gravação da tag NFC e cadastrar rosto, caso tenham sido puladas.
- Alterações só são salvas após confirmação, com mensagem de sucesso ou falha.

---

### US-10: Desativação e reativação de usuário
**Prioridade:** Must

**Como** administrador,
**quero** desativar um usuário em vez de excluí-lo,
**para** preservar o histórico de acessos (RF01, RF06, RF17).

**Critérios de aceite:**
- Ação de ativar ou desativar por `PATCH /users/{id}/status`.
- Confirmação antes de desativar, informando que o histórico é preservado.
- Usuário inativo aparece identificado na lista e pode ser reativado.

---

### US-11: Solicitação de gravação de tag NFC
**Prioridade:** Must

**Como** administrador,
**quero** pedir a gravação da tag NFC de um usuário,
**para** que ele passe a usar a tag no terminal de acesso (RF10).

**Critérios de aceite:**
- Botão "Gravar tag" na tela do usuário, que chama `POST /users/{id}/tags` informando o terminal onde a tag será gravada.
- O backend gera o código e comanda o ESP32 por MQTT. O app **não usa o NFC do celular** e não conhece o código gravado.
- Instrução na tela para aproximar a tag do leitor do terminal escolhido, dentro do tempo limite.
- Situação exibida a partir de `GET /users/{id}/tags`: aguardando a tag, gravada, falhou ou expirou.
- Mensagem clara se o terminal estiver offline ou ocupado.
- Possibilidade de repetir o pedido em caso de falha ou de tempo esgotado.

---

### US-12: Situação, revogação e substituição de tag NFC
**Prioridade:** Must

**Como** administrador,
**quero** ver a situação, revogar ou substituir a tag NFC de um usuário,
**para** manter os acessos corretos, inclusive em caso de perda da tag.

**Critérios de aceite:**
- Situação de cada tag (pendente, ativa, falha ou revogada) obtida por `GET /users/{id}/tags`.
- Revogação por `DELETE /users/{id}/tags/{tagId}`, com confirmação antes de revogar.
- Substituição disponível: revoga a tag antiga e pede a gravação de uma nova.
- O app nunca exibe o código gravado na tag.

---

### US-13: Termo de consentimento biométrico
**Prioridade:** Must

**Como** administrador,
**quero** exibir o termo de consentimento ao usuário e registrar o aceite antes de capturar o rosto,
**para** cumprir a LGPD no tratamento de dado biométrico (RNF02).

**Critérios de aceite:**
- O termo é exibido antes de qualquer captura facial.
- Sem o aceite, a captura não é liberada.
- O aceite é enviado ao backend junto com o cadastro facial, para registro com data.

---

### US-14: Captura facial com verificação de qualidade
**Prioridade:** Should

**Como** administrador,
**quero** que o app me oriente e valide a qualidade do rosto durante a captura,
**para** que o reconhecimento funcione bem depois.

**Critérios de aceite:**
- Câmera frontal ou traseira selecionável.
- ML Kit Face Detection verifica que há exatamente um rosto, de frente e com tamanho adequado, antes de aceitar o quadro.
- Orientações na tela (aproximar, melhorar a luz, olhar para a câmera).
- Imagens desfocadas ou escuras são rejeitadas.
- Permissão de câmera solicitada com explicação em linguagem simples.

---

### US-15: Geração de embedding facial e múltiplas amostras
**Prioridade:** Should

**Como** administrador,
**quero** que o app gere o embedding do rosto no próprio aparelho a partir de várias amostras,
**para** tornar o reconhecimento mais robusto a variações de ângulo e luz.

**Critérios de aceite:**
- Modelo TFLite (como MobileFaceNet) gera o vetor de cerca de 128 dimensões.
- Captura de 3 a 5 quadros (configurável na tela de configuração), com média dos embeddings ou envio de todos.
- Mesmo modelo e mesmo pré-processamento usados no mobile-readings.
- Nenhum dado biométrico fica armazenado no aparelho após o envio.

---

### US-16: Envio do cadastro facial ao backend
**Prioridade:** Should

**Como** administrador,
**quero** enviar embedding, versão do modelo e foto reduzida ao backend,
**para** que o rosto fique cadastrado e possa ser invalidado se o modelo mudar.

**Critérios de aceite:**
- Envio por `POST /users/{id}/face` (multipart), com embedding, `modelVersion`, data do consentimento e foto reduzida.
- Retry em caso de falha de rede, sem manter dados biométricos persistidos no aparelho.
- Mensagem clara de sucesso ou falha, e possibilidade de refazer a etapa.

---

### US-17: Foto reduzida do usuário
**Prioridade:** Should

**Como** administrador,
**quero** que a foto seja reduzida e limpa de metadados antes do envio,
**para** economizar tráfego e proteger a privacidade do usuário.

**Critérios de aceite:**
- Foto redimensionada (por exemplo, lado maior de 480 px) e comprimida em JPEG, reduzindo a qualidade progressivamente até cerca de 50 KB (limite configurável).
- Metadados EXIF removidos, inclusive localização.
- Testado em aparelhos de câmera de alta resolução para confirmar que a qualidade resultante é aceitável.

---

### US-18: Exibição da foto cadastrada
**Prioridade:** Could

**Como** administrador,
**quero** ver a foto cadastrada do usuário na lista e no detalhe,
**para** identificá-lo visualmente.

**Critérios de aceite:**
- Foto obtida por `GET /users/{id}/photo`, com o token de autenticação (não é servida como arquivo público).
- Imagem padrão exibida quando o usuário não tiver foto.
- A foto serve apenas à identificação visual, não ao reconhecimento.

---

### US-19: Exclusão dos dados biométricos
**Prioridade:** Should

**Como** administrador,
**quero** excluir definitivamente os dados biométricos de um usuário,
**para** atender a pedidos de remoção por razões de LGPD, separadamente da desativação.

**Critérios de aceite:**
- Ação distinta da desativação, disponível no detalhe do usuário.
- Confirmação explícita, informando que embedding e foto serão removidos de forma definitiva.
- O backend remove embedding, registro e arquivo da foto; o app reflete que não há mais rosto cadastrado.

---

### US-20: Pacote Dart comum de extração facial
**Prioridade:** Should

**Como** desenvolvedor,
**quero** compartilhar o código de extração de embedding com o mobile-readings em um pacote Dart interno,
**para** garantir que os embeddings dos dois apps sejam comparáveis.

**Critérios de aceite:**
- Pacote interno contendo modelo TFLite, pré-processamento, normalização e constante de `modelVersion`.
- Usado tanto pelo mobile-registry quanto pelo mobile-readings.
- Teste que confirma que a mesma imagem gera o mesmo embedding nos dois apps.
- Cliente da API, modelos e tela de configuração compartilháveis com os demais apps Flutter, quando fizer sentido.

---

### US-21: Interface acessível e simples
**Prioridade:** Must

**Como** administrador,
**quero** uma interface com botões grandes, textos claros e alto contraste,
**para** operar o app com facilidade, atendendo ao público idoso (RNF04).

**Critérios de aceite:**
- Botões com área de toque ampla e rótulos em texto, sem depender só de ícones.
- Fontes legíveis que respeitam o tamanho de texto do sistema.
- Mensagens em linguagem simples, sem termos técnicos.
- Indicador de carregamento em toda chamada à rede, para evitar toques repetidos.
- Rótulos semânticos (`Semantics`) nos elementos principais.

---

### US-22: Testes automatizados do aplicativo
**Prioridade:** Must

**Como** desenvolvedor,
**quero** testes automatizados para o mobile-registry,
**para** garantir a qualidade e permitir a execução no pipeline (RNF10).

**Critérios de aceite:**
- Testes unitários para repositórios, validações e interpretação das respostas da API.
- Testes de widget para login, listagem e assistente de cadastro.
- Teste de integração do fluxo de login até a criação de um usuário, com a API simulada.
- `flutter analyze` e `flutter test` executam sem erros.

---

## Pontos para sua decisão sobre este épico

- **Escopo de locais e autorizações (RF02 a RF05):** o docx atribui ao mobile-registry apenas usuários, tags e rosto, e deixa locais e autorizações no frontend. Mantive assim. O PDF do desafio, porém, descreve a administração como função do aplicativo móvel, e o próprio docx registra isso como decisão em aberto para confirmar com o professor. Se for decidido que o app também cobre isso, entram novas user stories neste épico.
- **Prioridade do facial:** o docx trata o reconhecimento facial como extra, então as stories de rosto (US-14 a US-17, US-19 e US-20) ficaram como **Should** e as de NFC e usuários como **Must**.

---

# Épico 2: mobile-readings

**Descrição:** aplicativo Flutter que faz o papel de Terminal de Acesso (RF11). Fica fixo junto à entrada, em um dispositivo dedicado, exibe o QR Code rotativo e o resultado do acesso e, como extra, reconhece rostos pela câmera. Não usa NFC: a leitura e a gravação das tags são feitas pelo ESP32. Permanece em repouso até que o sensor de presença do ESP32 detecte alguém. O app **não decide** a liberação: coleta a credencial e encaminha ao backend, que valida, registra o evento e publica o comando de abertura.

**Requisitos relacionados:** RF10, RF11, RF12, RF14, RF16, RNF03, RNF04, RNF07, RP03, RP04

---

### US-01: Estrutura base do aplicativo
**Prioridade:** Must

**Como** desenvolvedor,
**quero** um projeto Flutter organizado em camadas (telas, estado, repositórios e serviços),
**para** facilitar a manutenção e manter o mesmo padrão dos demais apps (RNF05).

**Critérios de aceite:**
- Estrutura de pastas separando telas, estado, repositórios e serviços (API, MQTT, câmera).
- Gerenciamento de estado definido (Riverpod ou Bloc), igual ao dos outros apps Flutter.
- O app compila e executa em um aparelho Android com câmera frontal.

---

### US-02: Tela de configuração do terminal
**Prioridade:** Must

**Como** responsável pela instalação do terminal,
**quero** configurar endereços, credenciais e parâmetros do terminal pelo próprio app,
**para** ajustá-lo ao trocar de rede, sem recompilar.

**Critérios de aceite:**
- Campos: endereço do backend (IP e porta), endereço do broker MQTT (IP e porta), credenciais do broker, identificador do terminal, tempo de inatividade antes de voltar ao repouso e limiar de similaridade facial.
- Valores persistidos em `shared_preferences` e aplicados sem reiniciar o app.
- Validação de formato dos campos, com mensagens claras.
- Android configurado com `usesCleartextTraffic` para HTTP na LAN, e permissão de câmera concedida.

---

### US-03: Cliente HTTP com autenticação do terminal e retry
**Prioridade:** Must

**Como** terminal de acesso,
**quero** me identificar ao backend com uma chave própria e repetir chamadas que falharam,
**para** que apenas terminais cadastrados enviem acessos e o funcionamento seja contínuo (RNF02, RNF03).

**Critérios de aceite:**
- Chave de API ou token próprio do terminal enviado em toda chamada de acesso (`/access/face`). A leitura de NFC não passa por este app: o ESP32 se autentica no broker MQTT.
- Camada única de acesso à API, com tratamento central de erros.
- Retry com limite de tentativas em falhas de rede e de timeout.
- Chave do terminal configurável e guardada de forma segura.

---

### US-04: Máquina de estados do terminal
**Prioridade:** Must

**Como** terminal de acesso,
**quero** controlar meu comportamento por estados bem definidos,
**para** reagir corretamente à presença, às credenciais e às respostas do backend.

**Critérios de aceite:**
- Estados implementados: Repouso, Escuta, Validando, Liberado e Negado.
- Transições conforme o projeto: presença leva de Repouso a Escuta; credencial lida leva a Validando; resposta leva a Liberado ou Negado; sem atividade por N segundos volta a Repouso; Liberado volta a Repouso e Negado volta a Escuta após poucos segundos.
- Transições cobertas por testes unitários.
- Estado atual visível apenas por meio da interface, sem telas de depuração em produção.

---

### US-05: Assinatura do evento de presença via MQTT
**Prioridade:** Must

**Como** terminal de acesso,
**quero** assinar o tópico de presença do ESP32 no broker,
**para** sair do repouso apenas quando alguém se aproximar.

**Critérios de aceite:**
- Conexão ao Mosquitto com o pacote `mqtt_client` por TCP na porta 1883.
- Assinatura de `terminal/{id}/presence`, usando credenciais com permissão somente de leitura nesse tópico (ACL).
- Ao receber o evento de presença, o app passa de Repouso para Escuta.
- Reconexão automática e keep-alive configurados (RNF03).
- Indicação discreta do estado da conexão com o broker.

---

### US-06: Fallback de presença por polling
**Prioridade:** Should

**Como** terminal de acesso,
**quero** consultar o backend quando o MQTT falhar,
**para** continuar detectando presença mesmo sem o broker.

**Critérios de aceite:**
- Se a conexão MQTT cair, o app consulta `GET /terminals/{id}/status` a cada 1 ou 2 segundos.
- Ao detectar presença pelo status, o app entra em Escuta como no fluxo normal.
- Quando o MQTT volta, o polling é interrompido.

---

### US-07: Exibição do QR Code rotativo
**Prioridade:** Must

**Como** usuário,
**quero** ver na tela do terminal um QR Code que se renova sozinho,
**para** lê-lo com o meu aplicativo e solicitar acesso (RF12).

**Critérios de aceite:**
- Token obtido em `GET /terminals/{id}/qr` e renovado a cada 10 segundos.
- O app apenas renderiza o texto recebido como QR Code, sem criar nem interpretar o token.
- QR Code visível enquanto o app estiver em Escuta, com tamanho adequado para leitura a distância.
- Renovação sem piscar nem travar a tela.

---

### US-08: QR Code indisponível em falha de conexão
**Prioridade:** Must

**Como** usuário,
**quero** ser avisado quando o QR Code não puder ser atualizado,
**para** não tentar ler um código vencido.

**Critérios de aceite:**
- Se a conexão com o backend falhar, o app deixa de exibir o QR e mostra o aviso "QR indisponível".
- Um token expirado nunca permanece na tela.
- Quando a conexão volta, o QR é exibido novamente de forma automática.

---

### US-09: Resultado do acesso por tag NFC
**Prioridade:** Must

**Como** usuário,
**quero** ver no terminal o resultado quando apresento minha tag ao leitor,
**para** saber se o acesso foi liberado ou negado (RF10, RF16).

**Critérios de aceite:**
- O app assina `terminal/{id}/result` no MQTT e, ao receber o resultado, exibe liberado ou negado com motivo genérico (ver US-11).
- O app **não lê NFC**: por definição do professor, a tag é lida pelo leitor do ESP32.
- Se o MQTT falhar, o app consulta `GET /terminals/{id}/status` por polling.
- Credenciais do broker com permissão somente de leitura nos tópicos `result` e `presence`, via ACL.

---

### US-10: Aviso de leitor ocupado na gravação de tag
**Prioridade:** Should

**Como** usuário,
**quero** ser avisado quando o leitor estiver gravando uma tag,
**para** usar o QR Code enquanto o leitor está ocupado.

**Critérios de aceite:**
- O app assina `terminal/{id}/status` e identifica o modo de gravação publicado pelo ESP32.
- Durante a gravação, exibe um aviso curto, por exemplo "Leitor NFC ocupado. Use o QR Code".
- O QR Code continua visível e o aviso some quando o ESP32 volta ao modo normal.

---

### US-11: Feedback visual do resultado do acesso
**Prioridade:** Must

**Como** usuário,
**quero** ver claramente se meu acesso foi liberado ou negado,
**para** saber se posso passar (RF16).

**Critérios de aceite:**
- Estado Liberado: tela verde, ícone de confirmação e texto "Acesso liberado".
- Estado Negado: tela vermelha, ícone e texto com motivo genérico, sem expor detalhes internos.
- Cor nunca é o único indicador: sempre acompanhada de ícone e texto.
- Liberado retorna a Repouso e Negado retorna a Escuta após poucos segundos.

---

### US-12: Comportamento seguro sem conexão com o backend
**Prioridade:** Must

**Como** administrador do prédio,
**quero** que o terminal negue o acesso quando não conseguir falar com o backend,
**para** que uma falha de rede nunca libere a entrada (RNF03).

**Critérios de aceite:**
- Sem resposta do backend após os retries, o resultado exibido é de erro e nunca "liberado".
- Não há cache de autorizações no terminal.
- A tela informa de forma simples que o sistema está indisponível.
- O app volta a funcionar normalmente assim que a conexão for restabelecida.

---

### US-13: Modo de repouso e economia de energia
**Prioridade:** Must

**Como** administrador do prédio,
**quero** que o terminal fique em repouso quando não houver ninguém por perto,
**para** reduzir o consumo e evitar leituras acidentais (RNF07).

**Critérios de aceite:**
- Em Repouso: tela econômica e câmera desligada.
- Em Escuta: câmera ativa (quando o facial estiver habilitado) e QR Code visível.
- Tempo de inatividade (N) configurável e respeitado.
- A câmera é liberada ao voltar para Repouso.

---

### US-14: Execução como terminal dedicado
**Prioridade:** Could

**Como** administrador do prédio,
**quero** que o app rode continuamente em um aparelho fixo na entrada,
**para** que o terminal não dependa de intervenção manual.

**Critérios de aceite:**
- App em tela cheia, sem que a tela do aparelho se apague durante a operação.
- O app retoma o funcionamento sozinho após ser reaberto ou após queda de conexão.
- Orientação de tela fixa, adequada à instalação.

---

### US-15: Sincronização dos embeddings faciais
**Prioridade:** Could

**Como** terminal de acesso,
**quero** baixar do backend os embeddings dos usuários autorizados,
**para** comparar rostos localmente (extra).

**Critérios de aceite:**
- Embeddings obtidos em `GET /terminals/{id}/faces` e mantidos apenas em memória.
- Regra de atualização definida e implementada (por exemplo, ao entrar em Escuta, a cada N minutos ou por evento do backend).
- Embeddings com `modelVersion` diferente do usado pelo app são descartados.
- Nenhum embedding é gravado em disco no aparelho.

---

### US-16: Detecção de rosto na câmera
**Prioridade:** Could

**Como** terminal de acesso,
**quero** localizar o rosto no quadro da câmera,
**para** iniciar o reconhecimento facial (extra).

**Critérios de aceite:**
- ML Kit Face Detection ativo apenas em Escuta, com a câmera frontal.
- Apenas quadros com um rosto de tamanho adequado seguem para o reconhecimento.
- Permissão de câmera tratada, com explicação em linguagem simples.
- A implementação só começa depois que QR Code e NFC estiverem estáveis.

---

### US-17: Reconhecimento facial local
**Prioridade:** Could

**Como** terminal de acesso,
**quero** gerar o embedding do rosto capturado e compará-lo aos embeddings autorizados,
**para** identificar o usuário sem transmitir imagens (extra).

**Critérios de aceite:**
- Embedding gerado com o modelo TFLite e o pré-processamento do pacote Dart comum, os mesmos do mobile-registry.
- Cálculo da distância ao rosto capturado, com correspondência definida pelo limiar configurável.
- Nenhuma imagem é transmitida durante o acesso.
- Sem correspondência acima do limiar, nada é enviado e o fluxo segue para as outras credenciais.

---

### US-18: Envio do resultado da identificação facial
**Prioridade:** Could

**Como** terminal de acesso,
**quero** enviar ao backend o resultado da identificação facial,
**para** que ele aplique as regras de autorização e registre o acesso (extra).

**Critérios de aceite:**
- Envio por `POST /access/face` com `{userId, terminalId, confiança}`, autenticado pela chave do terminal.
- O app passa a Validando e exibe o resultado como nos demais métodos.
- Intervalo mínimo entre envios para evitar registros duplicados do mesmo rosto.

---

### US-19: Calibração e limitações do reconhecimento facial
**Prioridade:** Could

**Como** equipe do projeto,
**quero** calibrar o limiar facial e documentar as limitações,
**para** apresentar o recurso com transparência.

**Critérios de aceite:**
- Limiar testado em condições reais de iluminação e registrado no documento do projeto.
- Documentadas as limitações: ausência de detecção de vivacidade (pode ser enganado por foto), sensibilidade à iluminação e necessidade de calibrar o limiar.
- Documentado que o backend confia no resultado do terminal, o que torna a autenticação do terminal essencial.

---

### US-20: Interface simples e acessível
**Prioridade:** Must

**Como** usuário,
**quero** textos e ícones grandes e mensagens simples no terminal,
**para** usá-lo sem dificuldade, inclusive sendo idoso (RNF04).

**Critérios de aceite:**
- Textos e ícones grandes, com alto contraste, legíveis a distância.
- Mensagens em linguagem simples, sem termos técnicos.
- Instrução curta e visível de como usar (ler o QR ou aproximar a tag).
- Testado com pessoas de mais idade antes da apresentação.

---

### US-21: Testes automatizados do aplicativo
**Prioridade:** Must

**Como** desenvolvedor,
**quero** testes automatizados para o mobile-readings,
**para** garantir a qualidade e permitir a execução no pipeline (RNF10).

**Critérios de aceite:**
- Testes unitários para a máquina de estados, o intervalo mínimo entre envios e a interpretação das respostas.
- Testes de widget para as telas de QR Code, Liberado e Negado.
- Teste de integração do fluxo de presença até o resultado, com API e MQTT simulados.
- `flutter analyze` e `flutter test` executam sem erros.

---

## Pontos para sua decisão sobre este épico

- **Reconhecimento facial como extra:** o docx diz que ele só deve ser implementado depois que QR Code e NFC estiverem estáveis. Por isso as stories US-15 a US-19 ficaram como **Could**.
- **Sincronização dos embeddings (US-15):** o docx deixa em aberto quando o app atualiza a lista (ao entrar em Escuta, a cada N minutos ou por evento do backend). Deixei a decisão como critério de aceite da story.
- **Sem NFC no terminal:** por definição do professor, a leitura de tags é feita pelo ESP32, então o aparelho do terminal não precisa de leitor NFC. A gravação das tags também é do ESP32.
- **Falha de rede:** adotei a opção mais segura citada no docx, negar por padrão e sem cache de autorizações (US-12).

---

# Épico 3: mobile-user

**Descrição:** aplicativo Flutter do usuário final (condômino ou visitante). É deliberadamente simples e tem três funções: autenticar o usuário, ler o QR Code exibido no Terminal de Acesso e mostrar as autorizações que ele possui. A leitura é feita dentro do app, e não pelo navegador, o que dá acesso direto ao GPS e dispensa a abertura de links. O app não valida o QR nem decide o acesso: repassa o token ao backend.

**Requisitos relacionados:** RF07, RF08, RF09, RF13, RF16, RNF02, RNF03, RNF04, RNF05, RP04, RP05

---

### US-01: Estrutura base do aplicativo
**Prioridade:** Must

**Como** desenvolvedor,
**quero** um projeto Flutter organizado em camadas (telas, estado, repositórios e serviços),
**para** facilitar a manutenção e manter o padrão dos demais apps Flutter (RNF05).

**Critérios de aceite:**
- Estrutura separando telas, estado, repositórios e serviços (API, localização, armazenamento seguro).
- Gerenciamento de estado definido (Riverpod ou Bloc), igual ao dos outros apps.
- Cliente da API, modelos e tela de configuração compartilháveis com os demais apps em um pacote Dart interno, evitando duplicação.
- O app compila e executa em um dispositivo Android real.

---

### US-02: Tela de configuração do endereço do backend
**Prioridade:** Must

**Como** usuário,
**quero** informar o endereço do backend no app,
**para** usá-lo em outra rede sem precisar recompilar.

**Critérios de aceite:**
- Tela de configuração com endereço do backend (IP e porta), salva em `shared_preferences`.
- Acessível antes do login.
- Validação do formato de IP e porta, com mensagem simples.
- Android com `usesCleartextTraffic` para HTTP na LAN, e permissões de câmera e localização declaradas. Em iOS, descrições de uso no `Info.plist` e exceção de ATS.

---

### US-03: Cliente HTTP único com tratamento de erros e retry
**Prioridade:** Must

**Como** usuário,
**quero** que o app tente novamente quando a rede falhar e me explique o problema,
**para** não ficar sem resposta em uma instabilidade momentânea (RNF03).

**Critérios de aceite:**
- Uma única camada de acesso à API, com tratamento central do token e dos erros.
- Retry com limite de tentativas em falhas de rede, sem reenviar de forma insegura a solicitação de acesso com token vencido.
- Mensagens em linguagem simples, sem termos como "token" ou "timeout".
- O app se comunica exclusivamente com o backend (RP05).

---

### US-04: Login do usuário
**Prioridade:** Must

**Como** condômino ou visitante,
**quero** entrar no app com usuário e senha,
**para** que o sistema saiba quem sou (RF07).

**Critérios de aceite:**
- Tela de login com usuário e senha, com opção de mostrar a senha.
- Autenticação por `POST /auth/login`, com token guardado em `flutter_secure_storage`.
- O app não tem tela de registro: contas são criadas por um administrador.
- Se o usuário já estiver autenticado, o app abre direto na tela inicial.
- Mensagem clara em caso de credenciais inválidas.

---

### US-05: Renovação de sessão e logout
**Prioridade:** Must

**Como** usuário,
**quero** continuar logado enquanto minha sessão for válida e poder sair quando quiser,
**para** não digitar a senha a toda hora e manter minha conta protegida (RNF02).

**Critérios de aceite:**
- Renovação do token por `POST /auth/refresh`, sem pedir a senha enquanto a sessão for válida.
- Quando a renovação falhar, o app leva ao login e explica o motivo.
- Logout limpa o token do armazenamento seguro.
- Nenhuma tela protegida fica acessível após o logout.

---

### US-06: Biometria do aparelho como atalho
**Prioridade:** Could

**Como** usuário com dificuldade de digitação,
**quero** reabrir o app com a biometria do meu aparelho,
**para** evitar digitar a senha com frequência.

**Critérios de aceite:**
- Uso de `local_auth` como atalho opcional, ativado pelo usuário.
- A biometria não substitui o login: apenas reabre uma sessão já existente.
- Se a biometria falhar ou não estiver disponível, o app oferece o login normal.

---

### US-07: Tela inicial simples
**Prioridade:** Must

**Como** usuário,
**quero** uma tela inicial com um botão grande "Abrir porta" e acesso às minhas autorizações,
**para** entender o que fazer sem esforço (RNF04).

**Critérios de aceite:**
- Botão grande "Abrir porta" que leva à leitura do QR.
- Acesso claro à lista de autorizações.
- Uma ação principal por tela, com poucos níveis de navegação.
- O fluxo exige poucos toques: abrir o app, tocar no botão e apontar a câmera.

---

### US-08: Leitura do QR Code do terminal
**Prioridade:** Must

**Como** usuário,
**quero** apontar a câmera para o QR Code do terminal,
**para** solicitar a abertura da porta (RF09).

**Critérios de aceite:**
- Leitura com o pacote `mobile_scanner`, com a câmera aberta apenas nessa tela e liberada ao sair.
- Moldura de enquadramento e instrução curta na tela.
- Ao ler o primeiro código válido, a câmera para, para não enviar o mesmo token várias vezes.
- Validação superficial apenas para filtrar QR Codes de fora do sistema (prefixo ou formato esperado), sem interpretar o conteúdo do token.
- Mensagem simples quando o código lido não pertencer ao sistema.

---

### US-09: Obtenção da localização do dispositivo
**Prioridade:** Must

**Como** usuário,
**quero** que o app obtenha minha localização no momento da leitura,
**para** comprovar que estou junto ao terminal (RF13).

**Critérios de aceite:**
- Pacote `geolocator`, com permissão solicitada no primeiro uso e explicada em linguagem simples ("para confirmar que você está junto à porta").
- Posição obtida em paralelo à abertura da tela da câmera, para já estar pronta quando o QR for lido.
- Posição recente em cache de poucos segundos usada como alternativa se a nova demorar.
- São enviados latitude, longitude e precisão (`accuracy`).
- A localização é enviada somente no momento da leitura, sem monitoramento contínuo nem armazenamento no aparelho.

---

### US-10: Detecção de localização falsa
**Prioridade:** Should

**Como** administrador do sistema,
**quero** saber quando a localização do dispositivo foi simulada,
**para** reduzir o risco de burla da checagem de proximidade.

**Critérios de aceite:**
- O app identifica *mock location* (`isMocked` no `geolocator`) e informa ao backend junto com a posição.
- O app não impede por conta própria: a decisão continua com o backend.
- Documentado que a falsificação de GPS é um risco conhecido que não se resolve apenas no app.

---

### US-11: Envio da solicitação de acesso por QR Code
**Prioridade:** Must

**Como** usuário,
**quero** que o app envie imediatamente o QR lido e minha localização ao backend,
**para** que a porta seja liberada dentro da validade do código (RF13).

**Critérios de aceite:**
- Envio por `POST /access/qr` com `{token, lat, lng, accuracy}`, autenticado com o token de login.
- Envio imediato após a leitura, sem telas intermediárias, pois o QR vale cerca de 10 segundos.
- Indicador de carregamento durante a validação, impedindo toques repetidos.
- O app não valida o QR nem decide o acesso: apenas repassa e exibe a resposta.
- Fluxo completo testado em rede lenta para confirmar que cabe na validade do token.

---

### US-12: Tela de resultado do acesso
**Prioridade:** Must

**Como** usuário,
**quero** ver de forma clara se o acesso foi liberado ou negado e por quê,
**para** saber o que fazer em seguida (RF16).

**Critérios de aceite:**
- Liberado: tela verde, ícone de confirmação e "Acesso liberado".
- Negado sem autorização: tela vermelha e "Você não tem autorização para este local".
- Negado fora do horário ou período: "Sua autorização não vale neste horário".
- Negado por usos esgotados: "Sua autorização já foi utilizada".
- Negado por distância: "Aproxime-se da porta e tente novamente".
- QR expirado: "O código venceu. Leia novamente".
- Erro de rede ou servidor: "Não foi possível conectar. Verifique o Wi-Fi".
- Os motivos são úteis ao usuário sem expor detalhes internos.

---

### US-13: Feedback acessível do resultado
**Prioridade:** Should

**Como** usuário com baixa visão ou daltonismo,
**quero** perceber o resultado por mais de um sinal além da cor,
**para** entender a resposta mesmo sem enxergar bem a tela (RNF04).

**Critérios de aceite:**
- Cada resultado combina cor, ícone grande e texto simples.
- Vibração curta ao exibir o resultado.
- Rótulos semânticos (`Semantics`) para leitores de tela na tela de resultado.

---

### US-14: Tratamento de permissões negadas e GPS desligado
**Prioridade:** Must

**Como** usuário,
**quero** ser orientado quando a câmera ou a localização estiverem bloqueadas,
**para** conseguir resolver o problema e concluir o acesso.

**Critérios de aceite:**
- Câmera ou localização negadas exibem uma explicação do motivo da permissão.
- Botão que leva o usuário às configurações do aparelho.
- GPS desligado gera orientação para ativá-lo, em vez de apenas um erro.
- O fluxo é retomado sem reiniciar o app depois de concedida a permissão.

---

### US-15: Lista de minhas autorizações
**Prioridade:** Must

**Como** usuário,
**quero** ver a lista das minhas autorizações de acesso,
**para** saber onde e quando posso entrar (RF08).

**Critérios de aceite:**
- Consulta a `GET /me/authorizations`, com as ativas primeiro.
- Cada item mostra local, período, janela de horário, usos restantes e situação (ativa, expirada ou cancelada).
- Puxar para atualizar.
- Mensagem clara quando a lista estiver vazia ("Você ainda não tem autorizações. Procure a administração").
- A rota usa a identidade do token, nunca um identificador enviado pelo cliente.

---

### US-16: Detalhe da autorização
**Prioridade:** Should

**Como** usuário,
**quero** abrir uma autorização e ver todos os detalhes,
**para** conferir local, datas, horários e usos restantes (RF08).

**Critérios de aceite:**
- Tela de detalhe com local, datas, horários, usos restantes e situação.
- Linguagem simples, sem termos técnicos.
- Navegação de volta para a lista.

---

### US-17: Cache local das autorizações para leitura
**Prioridade:** Could

**Como** usuário,
**quero** consultar minha última lista de autorizações mesmo sem conexão,
**para** conferir meus acessos quando estiver sem rede.

**Critérios de aceite:**
- A última lista obtida fica guardada apenas para leitura.
- Exibição de aviso de que os dados podem estar desatualizados.
- O cache nunca é usado para liberar acesso.
- Nenhum embedding ou foto é guardado no aparelho: somente o token e o cache de autorizações.

---

### US-18: Configuração por QR Code
**Prioridade:** Could

**Como** participante da apresentação,
**quero** configurar o app lendo um QR Code com o endereço do servidor,
**para** não digitar o IP no celular de cada pessoa.

**Critérios de aceite:**
- Opção na tela de configuração para ler um QR Code que contenha o endereço do backend.
- O endereço lido é validado e salvo como na configuração manual.
- A configuração manual continua disponível.

---

### US-19: Interface acessível e simples
**Prioridade:** Must

**Como** usuário idoso,
**quero** botões grandes, textos legíveis e mensagens simples,
**para** usar o app sem dificuldade (RNF04).

**Critérios de aceite:**
- Botões com área de toque ampla e rótulos em texto, sem depender só de ícones.
- Fontes legíveis que respeitam o tamanho de texto do sistema, e alto contraste.
- Mensagens sem termos técnicos.
- Indicação de carregamento nas chamadas à rede.
- Testado com pessoas de mais idade antes da apresentação.

---

### US-20: Tratamento de falhas de rede e novas tentativas
**Prioridade:** Should

**Como** usuário,
**quero** poder tentar de novo de forma simples quando a conexão falhar,
**para** concluir o acesso sem reiniciar o fluxo (RNF03).

**Critérios de aceite:**
- Em erro de rede, o resultado oferece um botão "Tentar novamente" que reabre a leitura do QR.
- Mensagem orienta a manter o Wi-Fi ativo ou desativar os dados móveis quando o Wi-Fi não tiver internet.
- O app nunca mostra "liberado" sem confirmação do backend.

---

### US-21: Testes automatizados do aplicativo
**Prioridade:** Must

**Como** desenvolvedor,
**quero** testes automatizados para o mobile-user,
**para** garantir a qualidade e permitir a execução no pipeline (RNF10).

**Critérios de aceite:**
- Testes unitários para os repositórios e a interpretação das respostas do backend.
- Testes de widget para as telas de resultado e de lista de autorizações.
- Teste de integração do fluxo de login até o resultado, com a API simulada.
- `flutter analyze` e `flutter test` executam sem erros.

---

## Pontos para sua decisão sobre este épico

- **Janela de 10 segundos:** o ciclo de ler o QR, obter o GPS e consultar o backend precisa caber na validade do token. O docx sugere que o backend aceite também o token anterior como tolerância. Isso é uma regra do backend, então fica para o épico 5.
- **iOS e distribuição:** instalar em iPhones exige conta de desenvolvedor ou TestFlight. As stories assumem Android como alvo principal. Se a turma tiver iPhones, é preciso definir se haverá alternativa.
- **Login do visitante:** o docx deixa em aberto como o visitante recebe o login (senha temporária ou convite) e como a conta expira com a autorização. Isso afeta backend e frontend, não gerei story no app.
- **Distribuição do APK:** a geração e disponibilização do APK pelo pipeline ficará no épico de DevOps.

---

# Épico 4: device-esp32

**Descrição:** dispositivo embarcado que representa o mecanismo físico de acesso (catraca ou porta). Tem cinco papéis: detectar a aproximação de uma pessoa (HC-SR04), **ler as tags NFC**, **gravar nas tags o código gerado pelo backend**, acionar a trava eletrônica quando o backend ordenar e sinalizar o resultado com buzzer e LED. O ESP32 não toma decisões de acesso: apenas obedece comandos recebidos via MQTT, publica o código lido da tag e reporta o que percebe. Há um único ESP32, que lê e grava. Junto com o mobile-readings (tela), forma o Terminal de Acesso (RF11).

**Requisitos relacionados:** RF10, RF11, RF14, RF15, RF16, RNF01, RNF03, RNF05, RNF07, RP02, RP03, RP08

---

### US-01: Projeto de firmware modular
**Prioridade:** Must

**Como** desenvolvedor,
**quero** um projeto PlatformIO com framework Arduino organizado em módulos,
**para** manter o firmware legível e testável (RNF05).

**Critérios de aceite:**
- Projeto PlatformIO criado, com dependências declaradas (PubSubClient ou AsyncMqttClient, ArduinoJson).
- Módulos separados: `config`, `net`, `mqtt`, `presence`, `lock`, `buzzer` e `main`.
- O firmware compila com `pio run` sem erros.
- Laço principal cooperativo baseado em `millis()`, sem `delay()` bloqueante.

---

### US-02: Configuração e gestão de segredos do firmware
**Prioridade:** Must

**Como** desenvolvedor,
**quero** concentrar pinos, limiares, tempos e credenciais em arquivos de configuração,
**para** ajustar o dispositivo sem mexer na lógica e sem expor segredos.

**Critérios de aceite:**
- `config.h` com SSID, senha do Wi-Fi, IP e porta do broker, usuário e senha do MQTT, identificador do terminal, limiar de distância e tempo de abertura da trava.
- `config.h` no `.gitignore` e `config.example.h` versionado.
- Mapeamento de pinos em um único arquivo, evitando os pinos de boot (0, 2, 12, 15) e os somente-entrada (34 a 39) para saídas.
- Atualização OTA protegida por senha ou desabilitada.

---

### US-03: Montagem do hardware e proteções elétricas
**Prioridade:** Must

**Como** equipe do projeto,
**quero** montar o circuito com as proteções necessárias,
**para** que o ESP32 e a trava funcionem sem queimar componentes nem reiniciar (RP02).

**Critérios de aceite:**
- Pino ECHO do HC-SR04 ligado ao ESP32 por divisor de tensão (por exemplo, 1 kΩ e 2 kΩ), conversor de nível ou sensor versão 3,3 V.
- Solenoide de 12 V alimentado por fonte separada, com GND comum ao ESP32, acionado por MOSFET ou relé com optoacoplador.
- Diodo de flyback em paralelo com a bobina.
- Buzzer e LED verde e vermelho ligados e testados.
- Teste de bancada confirmando que a trava não abre durante o boot, considerando relés que acionam em nível baixo.

---

### US-04: Conexão Wi-Fi com reconexão automática
**Prioridade:** Must

**Como** dispositivo,
**quero** conectar ao Wi-Fi e reconectar sozinho quando cair,
**para** manter o funcionamento contínuo (RNF03).

**Critérios de aceite:**
- Conexão ao Wi-Fi 2.4 GHz com as credenciais configuradas.
- Reconexão com intervalo crescente (backoff), sem travar o laço principal.
- O sensor e a trava continuam respondendo durante a tentativa de reconexão.
- Confirmado que o roteador ou hotspot da demonstração oferece a banda 2.4 GHz.

---

### US-05: Conexão MQTT com Last Will
**Prioridade:** Must

**Como** dispositivo,
**quero** manter conexão com o broker e informar meu estado,
**para** que o backend receba meus eventos e detecte quando eu cair (RP03).

**Critérios de aceite:**
- Conexão ao Mosquitto com usuário e senha exclusivos do ESP32.
- Assinatura de `terminal/{id}/command` apenas do próprio terminal.
- Last Will em `terminal/{id}/status` com `online: false`, e publicação retida de `online: true` ao conectar.
- Payload de status com `online`, `rssi`, `uptime` e `lockState`.
- Reconexão com backoff, sem travar o laço principal.
- Buffer do cliente MQTT ajustado (`setBufferSize`) para comportar os payloads.

---

### US-06: Leitura e filtragem do sensor HC-SR04
**Prioridade:** Must

**Como** dispositivo,
**quero** medir a distância de forma confiável,
**para** saber se há alguém à frente do terminal (RF11).

**Critérios de aceite:**
- Medição a cada 100 a 200 ms, com pulso no TRIG e `pulseIn` com timeout para não bloquear o laço.
- Leituras zero ou fora de faixa descartadas e mediana de 3 a 5 amostras.
- Limiar de distância configurável (por exemplo, 100 cm).
- Limiar calibrado em bancada com objetos a distâncias conhecidas, com o sensor posicionado na altura do tronco.

---

### US-07: Detecção e publicação de presença
**Prioridade:** Must

**Como** terminal de acesso,
**quero** publicar um evento quando alguém chegar ou sair,
**para** acordar o mobile-readings apenas quando necessário.

**Critérios de aceite:**
- Presença só é publicada após N leituras consecutivas abaixo do limiar, e a saída só após N leituras acima (debounce e histerese).
- Publicação em `terminal/{id}/presence` com `{detected, distance, ts}`, apenas em mudança de estado.
- Reenvio periódico opcional enquanto a presença persistir, para o app que se conectar depois.
- Um falso positivo apenas ativa o modo de escuta, nunca libera acesso.

---

### US-08: Recebimento e validação de comandos
**Prioridade:** Must

**Como** dispositivo,
**quero** validar cada comando recebido antes de executá-lo,
**para** evitar aberturas duplicadas, atrasadas ou indevidas (RNF03).

**Critérios de aceite:**
- Interpretação do payload `{action: "open" ou "deny", duration, requestId, expiresAt}` com `ArduinoJson`.
- `requestId` repetido é ignorado, guardando os últimos processados (o QoS 1 pode entregar o mesmo comando mais de uma vez).
- Comando com validade vencida é descartado, para que uma abertura atrasada por falha de rede não ocorra fora de hora.
- `duration` limitado por um teto no firmware (por exemplo, 10 s).
- Payloads inválidos ou desconhecidos são ignorados sem travar o dispositivo.

---

### US-09: Acionamento da trava eletrônica
**Prioridade:** Must

**Como** terminal de acesso,
**quero** abrir a trava quando o backend ordenar e fechá-la sozinho depois,
**para** liberar a entrada (RF15).

**Critérios de aceite:**
- Comando `open` aciona o pino de controle pelo tempo determinado e depois retorna ao estado fechado.
- Fechamento por temporizador baseado em `millis()`, sem `delay()`, para que o sensor e o MQTT sigam funcionando durante a abertura.
- Um novo `open` durante a abertura renova o tempo.
- Estado da trava refletido no campo `lockState` do status.

---

### US-10: Negação do acesso
**Prioridade:** Must

**Como** terminal de acesso,
**quero** manter a trava fechada e sinalizar quando o acesso for negado,
**para** deixar claro o resultado ao usuário (RF16).

**Critérios de aceite:**
- Comando `deny` mantém a trava fechada e aciona o padrão sonoro e visual de negação.
- Um `deny` não interrompe uma abertura já em curso.
- Estado Negando termina ao fim do padrão sonoro e retorna a Ocioso.

---

### US-11: Buzzer e LED não bloqueantes
**Prioridade:** Must

**Como** usuário,
**quero** ouvir e ver sinais distintos para acesso liberado e negado,
**para** entender a decisão sem olhar o celular (RF16).

**Critérios de aceite:**
- Liberado: 1 bipe curto e LED verde. Negado: 3 bipes curtos e LED vermelho.
- Opcionais: 1 bipe longo ao perder o broker, e sem som na detecção de presença.
- Padrões executados por uma máquina de estados não bloqueante.
- Buzzer ativo ou passivo definido e testado.

---

### US-12: Confirmação de execução dos comandos (ack)
**Prioridade:** Must

**Como** backend,
**quero** receber a confirmação de cada comando executado,
**para** saber se a abertura realmente aconteceu.

**Critérios de aceite:**
- Após acionar ou negar, publicação em `terminal/{id}/ack` com `{requestId, result, ts}`.
- Comandos descartados (repetidos ou vencidos) também geram ack com o resultado correspondente.
- O ack é publicado mesmo após reconexão, quando o comando já tiver sido executado.

---

### US-13: Máquina de estados do dispositivo
**Prioridade:** Must

**Como** dispositivo,
**quero** controlar meu comportamento por estados bem definidos,
**para** reagir corretamente a presença, comandos e quedas de conexão.

**Critérios de aceite:**
- Estados: Inicializando, Ocioso, Presença ativa, Liberando, Negando e Offline.
- Transições conforme o projeto (por exemplo, conectado leva a Ocioso, comando `open` leva a Liberando, reconectado sai de Offline).
- Em Offline, a trava permanece fechada e nenhum acesso é liberado.
- Lógica de estados separada do hardware, para ser testada no computador.

---

### US-14: Estado seguro e resiliência
**Prioridade:** Must

**Como** administrador do prédio,
**quero** que a trava tenha um comportamento seguro em falhas,
**para** evitar aberturas indevidas ou travamentos permanentes (RNF03).

**Critérios de aceite:**
- Trava sempre fechada após o boot.
- Watchdog do ESP32 habilitado para reiniciar em caso de travamento.
- Decisão entre fail-secure e fail-safe para a trava sem energia tomada e documentada.
- Fonte dimensionada e capacitor próximo à placa, testados com acionamentos repetidos para evitar brownout.

---

### US-15: Eficiência energética
**Prioridade:** Should

**Como** administrador do prédio,
**quero** que o dispositivo consuma pouca energia mantendo a operação contínua,
**para** atender ao requisito de eficiência (RNF07).

**Critérios de aceite:**
- Modo de economia de Wi-Fi (modem sleep) habilitado, sem prejudicar o recebimento de comandos.
- Frequência de medição reduzida quando ocioso por muito tempo.
- Impressão na serial limitada em operação normal.
- Deep sleep descartado e justificado: o ESP32 precisa ouvir comandos continuamente.

---

### US-16: Provisionamento de rede sem recompilar
**Prioridade:** Should

**Como** equipe do projeto,
**quero** trocar a rede Wi-Fi do dispositivo sem recompilar o firmware,
**para** lidar com a mudança de rede no dia da apresentação.

**Critérios de aceite:**
- Portal cativo com WiFiManager para informar SSID e senha.
- Parâmetros persistidos em NVS (Preferences) e mantidos após reinício.
- Broker, identificador do terminal, limiar de distância e tempo de abertura também configuráveis por esse meio.
- Caso a opção não seja implementada, a configuração por `config.h` segue funcionando.

---

### US-17: Validade dos comandos sem internet
**Prioridade:** Should

**Como** dispositivo,
**quero** avaliar a validade de um comando sem depender de horário da internet,
**para** descartar aberturas atrasadas mesmo na rede local sem acesso externo.

**Critérios de aceite:**
- Decisão tomada e implementada entre servidor NTP local no notebook ou validade relativa (por exemplo, `ttlMs` medido a partir da chegada do comando).
- Comando fora da validade é descartado e registrado no ack.
- A solução funciona na LAN de demonstração sem internet.

---

### US-18: Módulo GPS do terminal
**Prioridade:** Could

**Como** equipe do projeto,
**quero** incluir um módulo GPS no terminal,
**para** comprovar a presença do componente exigido em RF11.

**Critérios de aceite:**
- Módulo GPS (por exemplo, NEO-6M) ligado por UART e lido pelo firmware.
- O valor usado pelo sistema continua sendo a coordenada fixa cadastrada no backend, já que em ambiente fechado o GPS raramente terá fix.
- Resultado da leitura demonstrável (por exemplo, registrado na serial ou no status).

---

### US-19: Sensor de porta (reed switch)
**Prioridade:** Could

**Como** administrador do prédio,
**quero** saber se a porta realmente abriu e fechou,
**para** confirmar a abertura física no ack.

**Critérios de aceite:**
- Reed switch lido pelo firmware, com debounce.
- O estado da porta é incluído no ack e no status.
- O sistema funciona normalmente sem o sensor instalado.

---

### US-20: Simulador do dispositivo
**Prioridade:** Should

**Como** equipe do projeto,
**quero** um simulador que se comporte como o ESP32,
**para** testar backend e mobile-readings sem o hardware e ter um plano B na apresentação (RP08).

**Critérios de aceite:**
- Script (Node.js ou Python) que publica presença, status e ack, e assina `command`.
- Comandos `open` e `deny` produzem as mesmas respostas do firmware, inclusive tratamento de `requestId` repetido.
- Documentado como executar o simulador junto com o ambiente local.
- Testes manuais com `mosquitto_pub` e `mosquitto_sub` documentados.

---

### US-21: Testes do firmware
**Prioridade:** Must

**Como** desenvolvedor,
**quero** testes automatizados para a lógica do firmware,
**para** garantir a qualidade e validar o projeto no pipeline (RNF08, RNF10).

**Critérios de aceite:**
- Testes de unidade no computador, com o runner do PlatformIO, para debounce, filtro de mediana, interpretação de comandos, idempotência e máquina de estados.
- `pio run` e `pio test` executam sem erros.
- Testes de bancada registrados: calibração do sensor e acionamento repetido da trava com tempos e comandos variados.

---

### US-22: Leitor e gravador NFC ligado ao ESP32
**Prioridade:** Must

**Como** desenvolvedor,
**quero** ligar um módulo leitor e gravador NFC ao ESP32,
**para** ler e gravar as tags do terminal de acesso (RF10, RF11).

**Critérios de aceite:**
- Módulo de 13,56 MHz com leitura e escrita (por exemplo RC522 ou PN532) ligado por SPI ou I2C, em 3,3 V.
- Mapeamento de pinos definido no arquivo de configuração do firmware.
- Biblioteca escolhida e registrada na documentação.
- Tipo de tag com memória gravável (por exemplo NTAG ou MIFARE) definido e documentado.
- Teste de bancada de leitura e de escrita com mais de uma tag.

---

### US-23: Leitura do código da tag e publicação no MQTT
**Prioridade:** Must

**Como** terminal físico,
**quero** ler o código gravado na tag e publicá-lo no broker,
**para** que o backend valide o acesso (RF10, RF14).

**Critérios de aceite:**
- Leitura do código a partir da área de dados da tag.
- Publicação em `terminal/{id}/nfc` com `{code, uid, ts}` (o `uid` é opcional).
- Intervalo mínimo entre leituras da mesma tag, para evitar registros duplicados.
- Bipe curto ao ler a tag, e tag sem código válido não gera abertura.
- A leitura não bloqueia o laço principal, e o sensor e o MQTT continuam atendidos.

---

### US-24: Gravação do código na tag
**Prioridade:** Must

**Como** terminal físico,
**quero** gravar na tag o código enviado pelo backend,
**para** que o usuário passe a ter uma tag válida (RF10).

**Critérios de aceite:**
- Ao receber `terminal/{id}/enroll` com `{requestId, code, expiresAt}`, entra em modo de gravação por tempo limitado.
- Grava o código na próxima tag apresentada e lê de volta para conferir.
- Publica `ack` com `type: "enroll"` e resultado `written`, `failed` ou `timeout`.
- Bipes distintos para sucesso e falha.
- Pedidos vencidos ou repetidos (mesmo `requestId`) são descartados, sem gravar duas vezes.
- Durante a janela de gravação, publica `status` indicando o modo de gravação.

---

### US-25: Convivência de leitura e gravação no mesmo leitor
**Prioridade:** Should

**Como** terminal físico,
**quero** alternar entre leitura e gravação sem conflitos,
**para** que o acesso continue confiável com um único leitor.

**Critérios de aceite:**
- A máquina de estados inclui o estado "Gravando".
- Durante a gravação, leituras não são tratadas como tentativas de acesso, e o acesso por QR Code segue normalmente.
- Ao fim da gravação ou ao esgotar o tempo limite, o leitor volta ao modo de leitura.
- Testes de unidade para as transições entre os modos.

---

## Pontos para sua decisão sobre este épico

- **Fail-secure ou fail-safe:** o docx pede que a escolha seja decidida e documentada. Em um prédio real isso envolve segurança contra incêndio. Está na US-14.
- **Relógio sem internet:** a decisão entre NTP local e validade relativa está na US-17.
- **Leitor e gravador NFC no ESP32:** o professor definiu que a leitura de tags é feita pelo ESP32, e o Product Owner definiu que o mesmo ESP32 grava as tags com um código gerado pelo backend (US-22 a US-25). O mobile-readings não usa NFC. Falta definir o módulo (RC522 ou PN532) e o tipo de tag.
- **Confiabilidade do HC-SR04:** se os testes de bancada mostrarem instabilidade, o docx sugere considerar um sensor PIR ou óptico. Não gerei story para isso.
- **ACL do Mosquitto:** o tópico `command` é, na prática, a chave da fechadura, e só o backend deve poder publicar nele. A configuração do broker e das ACLs ficará no épico de DevOps.

---

# Épico 5: backend

**Descrição:** núcleo do sistema, em Node.js, Express e TypeScript, com PostgreSQL e disco local para as fotos. Concentra as regras de negócio, decide se cada acesso é liberado ou negado, persiste os dados e faz a ponte entre os apps (HTTP) e o ESP32 (MQTT). Nenhum outro serviço toma decisão de acesso: os apps coletam credenciais, o ESP32 executa comandos, e o backend valida, registra e ordena.

**Requisitos relacionados:** RF01 a RF08, RF12 a RF17, RNF01, RNF02, RNF03, RNF05, RNF06, RNF10, RNF12, RP01, RP03, RP05, RP07

---

### US-01: Estrutura base do backend
**Prioridade:** Must

**Como** desenvolvedor,
**quero** um projeto Node.js, Express e TypeScript organizado em módulos por domínio,
**para** manter o código modular e fácil de testar (RP01, RNF05).

**Critérios de aceite:**
- Módulos criados, cada um com rotas, serviço e repositório: `auth`, `users`, `locations`, `authorizations`, `access`, `terminals`, `mqtt`, `storage` e `audit`.
- Configuração por variáveis de ambiente, sem segredos no código.
- Validação de todos os payloads com esquema (por exemplo, `zod`) e tratamento centralizado de erros.
- Logs estruturados em JSON, com identificador de requisição, para facilitar a depuração (RNF12).
- `GET /health` disponível para Docker, CI/CD e monitoramento.

---

### US-02: Modelo de dados e migrações
**Prioridade:** Must

**Como** desenvolvedor,
**quero** modelar o banco PostgreSQL e versionar o esquema por migrações,
**para** recriar o banco de forma reproduzível (RNF06).

**Critérios de aceite:**
- Ferramenta de migração adotada (Prisma, TypeORM ou Knex).
- Tabelas criadas: `users`, `nfc_tags` (com o hash do código da tag e a situação), `face_templates`, `user_photos`, `locations`, `terminals`, `authorizations` e `access_logs`.
- `access_logs` aceita `user_id` nulo, para registrar tentativas com tag desconhecida (RF17).
- Embedding em coluna própria, separada dos dados cadastrais, com `model_version`.
- Datas armazenadas em UTC, com fuso `America/Sao_Paulo` definido para as regras de horário.
- Situação da autorização (ativa, cancelada ou expirada) com expiração calculável na consulta, sem rotina agendada.

---

### US-03: Autenticação e controle de perfis
**Prioridade:** Must

**Como** usuário do sistema,
**quero** me autenticar e ter acesso apenas ao que meu perfil permite,
**para** proteger os dados e as funções administrativas (RF07, RNF02).

**Critérios de aceite:**
- `POST /auth/login` e `POST /auth/refresh`, com token de acesso de vida curta.
- Senhas armazenadas com hash (bcrypt ou argon2).
- Rotas administrativas acessíveis apenas ao perfil de administrador.
- Condômino e visitante acessam somente os próprios dados.
- Limite de tentativas de login.

---

### US-04: Gestão de usuários
**Prioridade:** Must

**Como** administrador,
**quero** cadastrar, listar, editar e desativar usuários nos três perfis,
**para** manter a base de pessoas do sistema (RF01).

**Critérios de aceite:**
- `GET /users` com busca por nome ou documento, filtro por perfil e paginação.
- `POST /users` e `PUT /users/{id}`, com validação de campos e unicidade de documento.
- `PATCH /users/{id}/status` desativa e reativa, sem exclusão física, para preservar o histórico (RF06, RF17).
- Perfis: administrador, condômino e visitante.

---

### US-05: Gestão de tags NFC (código gerado e gravado pelo ESP32)
**Prioridade:** Must

**Como** administrador,
**quero** pedir a gravação e revogar tags NFC de um usuário,
**para** que ele possa acessar pelo terminal com a tag (RF10).

**Critérios de aceite:**
- `POST /users/{id}/tags` informando o terminal: o backend gera um código aleatório (por exemplo 128 bits), guarda **apenas o hash**, cria a tag como `pendente` e publica o pedido em `terminal/{id}/enroll`.
- Quando o ESP32 confirma a gravação (`ack` com `written`), a tag passa a `ativa`; em `failed` ou `timeout`, passa a `falha`, e o pedido pode ser repetido.
- `GET /users/{id}/tags` devolve a situação (pendente, ativa, falha ou revogada) e `DELETE /users/{id}/tags/{tagId}` revoga a tag, sem depender de apagar a tag física.
- O código em claro só trafega no pedido de gravação e nunca é registrado em log nem devolvido aos apps.
- Terminal offline ou ocupado resulta em erro claro, e pedidos de gravação expiram.

---

### US-06: Cadastro e exclusão de dados faciais
**Prioridade:** Should

**Como** administrador,
**quero** cadastrar e excluir o rosto de um usuário,
**para** habilitar o reconhecimento facial e atender à LGPD.

**Critérios de aceite:**
- `POST /users/{id}/face` (multipart) recebe embedding, `modelVersion`, data do consentimento e foto reduzida.
- Cadastro recusado sem registro de consentimento.
- Embedding armazenado em coluna separada e protegido no banco, com invalidação por `model_version`.
- Exclusão definitiva dos dados biométricos, separada da desativação do usuário, removendo embedding e registro da foto.
- Decisão registrada sobre alertar quando um novo embedding for muito parecido com o de outro usuário.

---

### US-07: Armazenamento local de fotos e entrega autenticada
**Prioridade:** Should

**Como** administrador,
**quero** que a foto reduzida seja armazenada com segurança e exibida só a quem tem permissão,
**para** identificar visualmente o usuário sem expor dados pessoais.

**Critérios de aceite:**
- Módulo `storage` com interface (`save`, `read`, `delete`) e implementação `LocalDiskStorage`, gravando na pasta definida por `PHOTOS_DIR`.
- Metadados em `user_photos` (caminho relativo, tamanho, tipo). Arquivo nomeado com UUID, nunca com nome ou documento do usuário.
- Upload limitado em tamanho (por exemplo, 100 KB), aceitando somente JPEG verificado pelo conteúdo real, com `multer` e limites explícitos.
- Proteção contra *path traversal*: caminho montado a partir do diretório base, rejeitando `..` e separadores.
- Foto entregue apenas por `GET /users/{id}/photo`, com autenticação e verificação de perfil, nunca como arquivo estático.
- Substituição grava o novo arquivo, atualiza o banco e só então apaga o anterior.
- Ao excluir dados de um usuário, o arquivo é removido do disco.

---

### US-08: Gestão de locais e terminais
**Prioridade:** Must

**Como** administrador,
**quero** cadastrar os locais controlados e os terminais vinculados a eles,
**para** definir onde as autorizações valem (RF02).

**Critérios de aceite:**
- `GET/POST /locations`, com edifício, portaria, porta, catraca e descrição.
- `GET/POST /terminals`, vinculando o terminal a um local, com latitude e longitude fixas.
- Cada terminal tem segredo próprio para o QR Code e estado de presença.
- Coordenada fixa do terminal usada na verificação de proximidade, conforme permitido por RP08.

---

### US-09: Autenticação dos terminais
**Prioridade:** Must

**Como** administrador do sistema,
**quero** que apenas terminais cadastrados enviem acessos por NFC e rosto,
**para** impedir que um cliente falso forje liberações (RNF02).

**Critérios de aceite:**
- Chave de API ou token próprio por terminal, gerado no cadastro do terminal.
- Chave exigida em `/access/face`, e rejeitada se inválida ou de outro terminal. Para o NFC, usuário e senha MQTT por terminal e ACL, de modo que só o ESP32 daquele terminal publique em `nfc`, `presence`, `status` e `ack`.
- Chave armazenada de forma segura (hash) e revogável.
- Documentado que o backend confia no resultado facial feito no terminal, o que torna esse o ponto mais frágil do fluxo.

---

### US-10: Gestão de autorizações e consulta pelo usuário
**Prioridade:** Must

**Como** administrador,
**quero** criar, consultar e cancelar autorizações, e como usuário quero ver as minhas,
**para** controlar quem pode entrar, onde e quando (RF03, RF04, RF05, RF08).

**Critérios de aceite:**
- `POST /authorizations` com pessoa, local, data de início e término, horário inicial e final, usos permitidos e situação.
- Validação de coerência (por exemplo, data de término posterior à de início).
- `GET /authorizations` com filtros por pessoa, local, período e situação, com paginação.
- `PATCH /authorizations/{id}/cancel`, mantendo o registro.
- `GET /me/authorizations` retorna apenas as do usuário autenticado, usando a identidade do token e nunca um identificador enviado pelo cliente, com as ativas primeiro.
- Contagem de usos realizados mantida em cada autorização.

---

### US-11: Geração do QR Code rotativo
**Prioridade:** Must

**Como** terminal de acesso,
**quero** receber a cada 10 segundos um token assinado para exibir como QR Code,
**para** que só quem esteja junto ao terminal consiga usá-lo (RF12).

**Critérios de aceite:**
- `GET /terminals/{id}/qr` devolve token assinado (HMAC ou JWT) com `terminalId`, `nonce` e expiração de cerca de 10 segundos.
- Token gerado exclusivamente no backend, assinado com o segredo do terminal.
- Nonces guardados até o token expirar (em memória ou tabela com TTL), para impedir reaproveitamento.
- Endpoint acessível apenas ao terminal correspondente.

---

### US-12: Núcleo de decisão de acesso e validação por NFC
**Prioridade:** Must

**Como** sistema,
**quero** uma única função de decisão de acesso, usada por todos os métodos,
**para** não duplicar regras e facilitar os testes (RF14).

**Critérios de aceite:**
- Módulo `access` com função de validação única, à qual QR, NFC e facial convergem, mudando só a forma de identificar a pessoa.
- Regras avaliadas: usuário ativo, autorização existente para o local, situação, janela de datas e horários, e usos restantes.
- Atualização atômica da contagem de usos (`UPDATE ... WHERE usos < limite`), para que acessos simultâneos não ultrapassem o limite.
- O backend assina `terminal/{id}/nfc`, calcula o hash do código recebido, localiza a tag ativa, identifica o usuário e aplica as regras, sem teste de geolocalização. Código desconhecido ou de tag revogada gera registro com usuário nulo e comando `deny`.
- Cada decisão devolve resultado e motivo, e aciona o registro do evento e a publicação do comando.

---

### US-13: Validação de acesso por QR Code
**Prioridade:** Must

**Como** usuário,
**quero** que o backend valide o QR lido e a minha localização,
**para** abrir a porta somente se eu estiver autorizado e junto ao terminal (RF13).

**Critérios de aceite:**
- `POST /access/qr` com `{token, lat, lng, accuracy}`, autenticado com o token do usuário.
- Ordem de validação: assinatura do token, expiração, nonce não reutilizado, depois as regras do núcleo de decisão, e por fim a proximidade geográfica.
- Distância calculada pela fórmula de Haversine entre a posição enviada e a coordenada do terminal, com raio configurável e consideração da `accuracy`.
- Indicação de localização simulada (*mock location*) enviada pelo app é registrada.
- Tolerância opcional de aceitar também o token imediatamente anterior, para absorver rede lenta.
- Respostas com motivos úteis ao usuário sem expor detalhes internos.

---

### US-14: Validação de acesso por reconhecimento facial
**Prioridade:** Could

**Como** terminal de acesso,
**quero** enviar o resultado de uma identificação facial e receber a decisão,
**para** liberar o acesso por rosto (extra).

**Critérios de aceite:**
- `GET /terminals/{id}/faces` entrega ao terminal os embeddings autorizados, com a respectiva `model_version`.
- `POST /access/face` com `{userId, terminalId, confiança}`, autenticado pela chave do terminal.
- Mesmas regras do núcleo de decisão aplicadas, registrando método e confiança.
- Embeddings com `model_version` desatualizada não são entregues.

---

### US-15: Integração MQTT e comandos ao ESP32
**Prioridade:** Must

**Como** sistema,
**quero** publicar no broker o comando de abertura ou negação para o terminal,
**para** acionar a trava e a sinalização conforme a decisão (RF15, RF16).

**Critérios de aceite:**
- Cliente MQTT do backend com usuário próprio, reconexão automática e retry (RNF03).
- Publicação em `terminal/{id}/command` com `{action: "open" ou "deny", duration, requestId, expiresAt}`, em QoS 1, com validade curta.
- Negação também publicada, para acionar o buzzer.
- Lógica de publicação exposta por interface (`CommandPublisher`), permitindo trocar o MQTT por um *mock* nos testes.
- Publicação em `terminal/{id}/enroll` com `{requestId, code, expiresAt}` para a gravação de tags, e do resultado do acesso em `terminal/{id}/result`, para a tela do terminal.
- Assinatura de `terminal/{id}/nfc`, e de `terminal/{id}/ack` também para os pedidos de gravação (`type: "enroll"`).
- Assinatura de `terminal/{id}/ack`, associando o `requestId` ao evento de acesso para confirmar a abertura real.
- Se o broker estiver indisponível, o acesso é registrado como autorizado, mas com a indicação de que o comando não foi entregue, e o app recebe erro em vez de "liberado".

---

### US-16: Presença e estado dos terminais
**Prioridade:** Must

**Como** sistema,
**quero** receber e disponibilizar o estado de cada terminal,
**para** que os apps e o dashboard saibam se há alguém presente e se o terminal está online.

**Critérios de aceite:**
- Assinatura de `terminal/{id}/presence` e `terminal/{id}/status`, guardando último estado e horário em `terminals`.
- Detecção de queda do dispositivo pelo Last Will.
- `GET /terminals/{id}/status` devolve presença, estado online ou offline, último horário e estado da trava, usado como fallback pelo mobile-readings.

---

### US-17: Registro e consulta do histórico de acessos
**Prioridade:** Must

**Como** administrador,
**quero** consultar todas as tentativas de acesso,
**para** ter rastreabilidade do que aconteceu (RF06, RF17).

**Critérios de aceite:**
- Toda tentativa é registrada, liberada ou negada, com usuário (nulo se desconhecido), terminal, método (QR, NFC ou facial), resultado, motivo exato e data e hora.
- `GET /access-logs` com filtros por período, pessoa, terminal, método e resultado, com paginação no servidor.
- Exportação do histórico disponível para o frontend.
- Regra de retenção do histórico definida, inclusive o que fazer com ele quando um usuário for removido.

---

### US-18: Endpoints agregados do dashboard
**Prioridade:** Should

**Como** administrador,
**quero** receber números agregados do sistema,
**para** acompanhar a operação sem baixar todo o histórico.

**Critérios de aceite:**
- `GET /dashboard/summary` com acessos liberados e negados no dia, taxa de negação, acessos por método e autorizações ativas, expirando e canceladas.
- `GET /dashboard/accesses-by-hour` com a série por hora.
- Motivos de negação mais frequentes disponíveis.
- Consultas eficientes, sem varrer todo o histórico a cada chamada.

---

### US-19: Segurança transversal da API
**Prioridade:** Must

**Como** administrador do sistema,
**quero** proteções gerais na API,
**para** reduzir riscos de abuso e vazamento (RNF02).

**Critérios de aceite:**
- Limite de requisições (`express-rate-limit`) nos endpoints de login e de acesso.
- CORS liberando apenas a origem do frontend, e não `*`.
- Cabeçalhos de segurança e proteção contra entradas inválidas em todos os payloads.
- Segredos (chaves, senhas do banco e credenciais do broker) somente em variáveis de ambiente.
- HTTP na LAN aceito como limitação declarada, com HTTPS previsto para um cenário real.

---

### US-20: Especificação OpenAPI
**Prioridade:** Should

**Como** equipe do projeto,
**quero** uma especificação OpenAPI versionada de todos os endpoints,
**para** que os três clientes e a documentação sigam o mesmo contrato (RP07).

**Critérios de aceite:**
- Todos os endpoints consolidados em uma especificação OpenAPI.
- Especificação publicada junto com a API e versionada no repositório.
- Tipos do frontend podem ser gerados a partir dela.
- Alterações no contrato passam por revisão para não quebrar os clientes sem aviso.

---

### US-21: Testes automatizados do backend
**Prioridade:** Must

**Como** desenvolvedor,
**quero** testes automatizados das regras de negócio e dos endpoints,
**para** garantir a qualidade e permitir a execução no pipeline (RNF10).

**Critérios de aceite:**
- Testes unitários das regras de validação: data, horário, usos, distância, expiração e reuso do token.
- Testes de integração dos endpoints de acesso, com banco de teste e MQTT simulado por meio do `CommandPublisher`.
- Teste de concorrência para a contagem atômica de usos.
- Testes executam sem erros localmente e no pipeline.

---

## Pontos para sua decisão sobre este épico

- **Raio de proximidade (RF13):** o PDF diz "pelo menos 100 metros", mas o docx interpreta como no máximo 100 metros do terminal. Implementei o raio configurável na US-13, e a ambiguidade merece ser confirmada com o professor.
- **Banco em nuvem (RNF06):** o requisito pede banco em nuvem, e a decisão atual é PostgreSQL local. A provisão de uma instância em nuvem pelo pipeline não está neste épico e ficará no de DevOps.
- **Retenção do histórico:** a regra de por quanto tempo guardar o histórico está nos critérios da US-17, mas depende de uma decisão do grupo.
- **Login do visitante:** o docx deixa em aberto como o visitante recebe a conta (senha temporária ou convite) e como ela expira junto com a autorização. Não gerei story específica.
- **Escopo do reconhecimento facial:** como extra, as stories US-06, US-07 e US-14 ficaram como **Should** e **Could**.
- **Docker, CI/CD e deploy (RP09 a RP12):** ficam no épico de DevOps.

---

# Épico 6: frontend

**Descrição:** interface web de administração e monitoramento, usada no computador da portaria ou da administração apenas por administradores. Tem duas funções: **gerir** (usuários, locais, terminais e autorizações) e **acompanhar** (dashboard com acessos e estado dos terminais). É o único serviço que cobre toda a administração prevista nos requisitos e também a redundância do mobile-registry para o cadastro básico. Como nos demais serviços, o frontend não decide nada: apresenta dados e envia comandos, e o backend valida.

**Requisitos relacionados:** RF01 a RF07, RF11, RF17, RNF01, RNF02, RNF04, RNF05, RNF10, RP05

---

### US-01: Estrutura base do frontend
**Prioridade:** Must

**Como** desenvolvedor,
**quero** um projeto React com TypeScript e Vite organizado por funcionalidade,
**para** manter o código modular e na mesma linguagem do backend (RNF05).

**Critérios de aceite:**
- Projeto criado com React, TypeScript e Vite, usando React Router e TanStack Query.
- Pastas por funcionalidade (`features/auth`, `users`, `locations`, `authorizations`, `access-logs` e `dashboard`) e pasta `shared` com cliente HTTP, componentes comuns e utilitários.
- Biblioteca de componentes definida (por exemplo, MUI ou shadcn/ui) e Recharts ou similar para gráficos.
- Layout base com menu de navegação entre as telas.
- Formulários com React Hook Form e `zod`.

---

### US-02: Cliente HTTP único
**Prioridade:** Must

**Como** desenvolvedor,
**quero** uma camada única de acesso à API,
**para** centralizar token, erros e expiração de sessão (RP05).

**Critérios de aceite:**
- Todas as chamadas à API passam pelo mesmo cliente.
- Token enviado automaticamente, com tratamento central de erros e de resposta 401.
- Quando possível, tipos gerados a partir da especificação OpenAPI do backend, evitando divergência de contrato.
- O frontend se comunica apenas com a API REST.

---

### US-03: Login do administrador e proteção de rotas
**Prioridade:** Must

**Como** administrador,
**quero** entrar no sistema com usuário e senha,
**para** acessar as funções de administração com segurança (RF07).

**Critérios de aceite:**
- Tela de login com usuário e senha, restrita a administradores.
- Token de acesso de vida curta mantido preferencialmente em memória, com renovação por `POST /auth/refresh`, sem usar `localStorage`.
- Rotas protegidas por perfil: usuários sem permissão são redirecionados.
- Sessão expirada leva ao login com mensagem clara.
- Botão de sair encerra a sessão.
- O frontend apenas esconde o que o usuário não pode usar, pois o backend continua sendo a barreira real.

---

### US-04: Lista de usuários
**Prioridade:** Must

**Como** administrador,
**quero** listar usuários com busca e filtro por perfil,
**para** encontrar rapidamente quem preciso gerenciar (RF01).

**Critérios de aceite:**
- Lista com busca por nome ou documento e filtro por perfil (administrador, condômino ou visitante).
- Paginação feita no servidor.
- Cada linha mostra perfil, situação e indicação de tag e rosto cadastrados.
- Estados de carregamento, vazio e erro tratados.

---

### US-05: Cadastro, edição e desativação de usuários
**Prioridade:** Must

**Como** administrador,
**quero** criar, editar e desativar usuários,
**para** manter a base de pessoas atualizada (RF01).

**Critérios de aceite:**
- Formulário de criação e edição com validação de campos, e erros do backend exibidos junto ao campo.
- Ativação e desativação por `PATCH /users/{id}/status`, com confirmação antes de desativar.
- Os três perfis disponíveis no formulário.
- Mesma API usada pelo mobile-registry, com o mesmo comportamento.

---

### US-06: Detalhe do usuário
**Prioridade:** Must

**Como** administrador,
**quero** ver em uma tela os dados, a foto, as tags, a situação do rosto e as autorizações de um usuário,
**para** ter a visão completa de quem ele é e do que pode acessar (RF01, RF03).

**Critérios de aceite:**
- Dados cadastrais, foto reduzida (quando existir), tags vinculadas e autorizações do usuário.
- Foto obtida por requisição autenticada e exibida via `URL.createObjectURL`, já que uma tag `<img>` não envia o cabeçalho `Authorization`.
- Indicação se o usuário tem ou não rosto cadastrado, sem exibir o embedding. Quando não tiver, orienta a usar o mobile-registry.
- Exibição apenas do necessário do documento do usuário.

---

### US-07: Pedido de gravação de tag NFC pelo navegador
**Prioridade:** Must

**Como** administrador,
**quero** pedir a gravação e revogar tags NFC pelo navegador,
**para** manter o cadastro possível se o aplicativo falhar (RF10).

**Critérios de aceite:**
- Botão "Gravar tag" no detalhe do usuário, que chama `POST /users/{id}/tags` informando o terminal.
- Instrução na tela para aproximar a tag do leitor do terminal, dentro do tempo limite.
- Situação da tag (pendente, ativa, falha ou revogada) obtida por `GET /users/{id}/tags`, com mensagem clara para falha e tempo esgotado.
- Revogação por `DELETE /users/{id}/tags/{tagId}`, com confirmação.
- O navegador não lê nem grava NFC: leitor USB e Web NFC não são usados, porque a gravação é feita pelo ESP32. O frontend e o app têm os mesmos endpoints.

---

### US-08: Foto do usuário pelo navegador
**Prioridade:** Could

**Como** administrador,
**quero** enviar ou capturar a foto de um usuário pelo navegador,
**para** completar o cadastro quando o aplicativo não estiver disponível.

**Critérios de aceite:**
- Upload de arquivo ou captura por webcam.
- Redimensionamento no navegador (canvas) até cerca de 50 KB e remoção de EXIF.
- A webcam funciona apenas em contexto seguro: localhost ou HTTPS, e a limitação é informada na tela.
- Cadastro do embedding facial fora do escopo: o frontend não gera embeddings.

---

### US-09: Cadastro de locais e terminais
**Prioridade:** Must

**Como** administrador,
**quero** cadastrar locais controlados e terminais vinculados a eles,
**para** definir onde as autorizações valem (RF02, RF11).

**Critérios de aceite:**
- Tela de locais com edifício, portaria, porta, catraca e localização, com criação e edição.
- Tela de terminais vinculando cada terminal a um local, com coordenada fixa.
- Exibição do estado do terminal (online ou offline) e da última presença.
- Chave do terminal exibida uma única vez no momento da criação, para ser configurada no mobile-readings.

---

### US-10: Lista de autorizações com filtros
**Prioridade:** Must

**Como** administrador,
**quero** consultar autorizações com filtros,
**para** saber quem pode acessar o quê (RF04).

**Critérios de aceite:**
- Lista com filtros por pessoa, local, período e situação.
- Paginação feita no servidor.
- Cada linha mostra pessoa, local, período, horário, usos restantes e situação (ativa, expirada ou cancelada).
- Estados de carregamento, vazio e erro tratados.

---

### US-11: Criação de autorização
**Prioridade:** Must

**Como** administrador,
**quero** criar uma autorização de acesso,
**para** liberar uma pessoa em um local por um período (RF03).

**Critérios de aceite:**
- Formulário com pessoa, local, data de início e término, horário inicial e final, e quantidade de usos permitidos.
- Mensagens específicas de validação (por exemplo, "a data de término deve ser posterior à de início").
- Datas enviadas em UTC e exibidas em `America/Sao_Paulo`.
- Confirmação de sucesso, com retorno à lista.

---

### US-12: Cancelamento de autorização
**Prioridade:** Must

**Como** administrador,
**quero** cancelar uma autorização,
**para** retirar um acesso que não deve mais valer (RF05).

**Critérios de aceite:**
- Ação de cancelar na lista e no detalhe, por `PATCH /authorizations/{id}/cancel`.
- Confirmação antes de cancelar, informando que a ação não pode ser desfeita.
- A autorização permanece visível com a situação cancelada.

---

### US-13: Histórico de acessos
**Prioridade:** Must

**Como** administrador,
**quero** consultar o histórico de tentativas de acesso com filtros,
**para** auditar quem entrou e quem foi negado (RF06, RF17).

**Critérios de aceite:**
- Lista com filtros por período, pessoa, terminal, método (QR, NFC ou facial) e resultado.
- Paginação e filtros feitos no servidor.
- Cada linha mostra data e hora, pessoa, terminal, método, resultado e motivo.
- Estados de carregamento, vazio e erro tratados.

---

### US-14: Exportação do histórico
**Prioridade:** Could

**Como** administrador,
**quero** exportar o histórico filtrado,
**para** analisá-lo ou arquivá-lo fora do sistema.

**Critérios de aceite:**
- Exportação do resultado dos filtros atuais em arquivo (por exemplo, CSV).
- Uso do endpoint de exportação do backend, sem montar o arquivo a partir de toda a base no navegador.
- Aviso de que o arquivo contém dados pessoais.

---

### US-15: Dashboard: indicadores
**Prioridade:** Should

**Como** administrador,
**quero** ver números e gráficos de acesso,
**para** entender a operação e demonstrar o sistema funcionando.

**Critérios de aceite:**
- Acessos liberados e negados no dia e taxa de negação.
- Acessos por método (QR, NFC e facial) e por hora, em gráfico de linha ou barras.
- Autorizações ativas, expirando em breve e canceladas.
- Motivos de negação mais frequentes.
- Dados obtidos de `GET /dashboard/summary` e `GET /dashboard/accesses-by-hour`, sem baixar todo o histórico.

---

### US-16: Dashboard: monitoramento em tempo quase real
**Prioridade:** Should

**Como** administrador,
**quero** acompanhar os últimos eventos e o estado dos terminais,
**para** ver o sistema funcionando e perceber falhas rapidamente.

**Critérios de aceite:**
- Lista dos últimos eventos de acesso, atualizada automaticamente por *polling* a cada poucos segundos.
- Cartão por terminal com status (online ou offline), última presença e estado da trava, a partir de `GET /terminals/{id}/status`.
- Atualização via TanStack Query, com tratamento de erro quando a atualização falhar.
- Atualização por SSE considerada apenas se sobrar tempo.

---

### US-17: Configuração independente do endereço do servidor
**Prioridade:** Should

**Como** equipe do projeto,
**quero** que o frontend não dependa do IP do backend embutido no build,
**para** trocar de rede na apresentação sem refazer o build.

**Critérios de aceite:**
- Frontend usa caminho relativo (`/api`), com o proxy reverso no Nginx do Compose encaminhando ao backend.
- Alternativa documentada: `config.json` lido em tempo de execução e editável sem rebuild.
- O proxy também elimina o problema de CORS entre origens diferentes.
- Documentado que frontend e backend devem usar o mesmo esquema (HTTP ou HTTPS), para evitar bloqueio de conteúdo misto.

---

### US-18: Usabilidade e acessibilidade
**Prioridade:** Should

**Como** administrador,
**quero** uma interface clara e acessível,
**para** operar o sistema sem dificuldade e sem erros (RNF04).

**Critérios de aceite:**
- Contraste adequado, fontes legíveis, foco visível no teclado e rótulos claros nos formulários.
- Mensagens de erro específicas, em vez de erros genéricos.
- Confirmação antes de ações destrutivas, como cancelar autorização ou desativar usuário.
- Estados de carregamento, vazio e erro em todas as telas, para não parecer travado durante a apresentação.
- Datas exibidas em `America/Sao_Paulo`.
- Layout responsivo para uso em tablet, sem prioridade de design mobile.

---

### US-19: Segurança e privacidade no frontend
**Prioridade:** Must

**Como** administrador do sistema,
**quero** que o frontend proteja a sessão e os dados pessoais,
**para** reduzir riscos de vazamento (RNF02).

**Critérios de aceite:**
- Token fora do `localStorage`.
- Sem `dangerouslySetInnerHTML`, tratando campos livres (nome, descrição) como texto, para evitar XSS.
- Embeddings nunca exibidos, e documento mostrado apenas no necessário.
- Finalidade da exibição de nomes e horários de entrada documentada, em atenção à LGPD.
- Funciona com HTTP na LAN de demonstração, com a limitação declarada.

---

### US-20: Testes automatizados do frontend
**Prioridade:** Must

**Como** desenvolvedor,
**quero** testes automatizados do frontend,
**para** garantir a qualidade e permitir a execução no pipeline (RNF10).

**Critérios de aceite:**
- Testes unitários e de componentes com Vitest e Testing Library (formulários, filtros e regras de exibição).
- API simulada com MSW, para testar sem o backend.
- Teste ponta a ponta com Playwright cobrindo o fluxo principal: login, criar usuário, criar autorização e ver no histórico.
- Verificação de tipos, lint (ESLint) e testes executam sem erros localmente e no pipeline.

---

## Pontos para sua decisão sobre este épico

- **Escopo da redundância:** o embedding facial não é cadastrado pelo frontend, mas o pedido de gravação de tags NFC tem paridade com o app, pois a gravação é feita pelo ESP32. É preciso decidir se a ausência do facial é aceitável como redundância ou se o frontend precisa de paridade total.
- **Quem administra:** o PDF descreve a administração como função do aplicativo móvel, mas hoje locais e autorizações só existem no frontend. Confirmar com o professor se isso é aceito, ou se o mobile-registry precisa de telas de autorizações.
- **Prioridade do dashboard:** o docx observa que o dashboard é o que mais impressiona na apresentação, mas também o que mais consome tempo, e recomenda priorizar login, usuários, autorizações e histórico. Por isso as stories do dashboard ficaram como **Should**.
- **Nginx e Docker:** o proxy reverso e o build multi-estágio em contêiner ficam no épico de DevOps. A US-17 cobre apenas o comportamento do frontend.
- **Webcam e HTTP:** a câmera no navegador só funciona em contexto seguro, então a US-08 só vale se o admin abrir o frontend no notebook do servidor ou se houver HTTPS.

---

# Épico 7: DevOps

**Descrição:** infraestrutura, conteinerização, pipelines de CI/CD e ambiente de demonstração do projeto. Garante que backend, Mosquitto, PostgreSQL e frontend subam de forma padronizada via Docker Compose em um notebook na LAN, que cada commit seja construído, analisado e testado automaticamente, e que o backend seja publicado de forma automatizada. Inclui a configuração do broker e de suas ACLs, que protegem o tópico de comando da fechadura.

**Requisitos relacionados:** RNF02, RNF03, RNF06, RNF08, RNF09, RNF10, RNF11, RNF12, RP09, RP10, RP11, RP12

---

### US-01: Estratégia de versionamento Git
**Prioridade:** Must

**Como** equipe do projeto,
**quero** definir a organização dos repositórios e o fluxo de branches,
**para** trabalhar em paralelo sem conflitos e com histórico rastreável (RNF11).

**Critérios de aceite:**
- Decisão registrada entre repositório único ou um repositório por serviço.
- Estratégia de branches definida (Git Flow ou similar), com branches `main` e de desenvolvimento protegidas.
- Padrão de commits descritivos acordado (por exemplo, Conventional Commits).
- Pull requests com revisão e execução do pipeline antes do merge.
- `.gitignore` adequado em cada serviço, incluindo `config.h` do firmware e arquivos `.env`.

---

### US-02: Imagens Docker do backend e do frontend
**Prioridade:** Must

**Como** equipe do projeto,
**quero** imagens Docker padronizadas dos serviços,
**para** executar o sistema igual em qualquer máquina (RP12).

**Critérios de aceite:**
- Dockerfile do backend em build multi-estágio, com imagem final enxuta, executando com usuário sem privilégios e com escrita permitida somente na pasta de fotos.
- Dockerfile do frontend em build multi-estágio (build com Node e imagem final com Nginx servindo os arquivos estáticos).
- Nginx do frontend com proxy reverso (`/api` aponta para o backend), para o frontend não depender do IP.
- Healthcheck definido nas imagens, usando `GET /health` no backend.
- Imagens constroem sem erros localmente e no pipeline.

---

### US-03: Docker Compose do ambiente completo
**Prioridade:** Must

**Como** equipe do projeto,
**quero** subir todo o ambiente com um único comando,
**para** montar a demonstração rapidamente e reproduzir o ambiente de desenvolvimento (RP12).

**Critérios de aceite:**
- `docker-compose` com backend, PostgreSQL, Mosquitto e frontend.
- Volume para os dados do banco e volume (ou *bind mount*) para `/photos`, para que sobrevivam à recriação dos containers.
- Ordem de inicialização e *healthchecks* configurados, com reinício automático.
- Configuração por variáveis de ambiente, sem segredos no arquivo versionado.
- Documentado o comando de subida e o de parada, e como recriar o ambiente do zero.

---

### US-04: Configuração do Mosquitto com usuários e ACLs
**Prioridade:** Must

**Como** administrador do sistema,
**quero** que cada cliente MQTT tenha usuário próprio e permissões mínimas,
**para** que ninguém além do backend consiga abrir a trava (RNF02).

**Critérios de aceite:**
- Autenticação por usuário e senha, sem acesso anônimo.
- Usuário do backend com permissão de publicar em `terminal/{id}/command` e de assinar presença, status e ack.
- Usuário do ESP32 com permissão de publicar em `presence`, `ack` e `status`, e de assinar apenas o `command` do próprio terminal.
- Usuário do mobile-readings com permissão somente de leitura em `terminal/{id}/presence`.
- Teste com `mosquitto_pub` e `mosquitto_sub` confirmando que um cliente sem permissão não consegue publicar em `command`.
- Persistência e *keep-alive* configurados, na porta 1883, com a ausência de TLS declarada como limitação na LAN.

---

### US-05: Gestão de variáveis de ambiente e segredos
**Prioridade:** Must

**Como** equipe do projeto,
**quero** manter segredos fora do repositório,
**para** evitar vazamento de senhas e chaves (RNF02).

**Critérios de aceite:**
- `.env.example` versionado, listando todas as variáveis sem valores reais, e `.env` ignorado pelo Git.
- Chaves, senhas do banco e credenciais do broker apenas em variáveis de ambiente.
- Segredos do pipeline guardados no mecanismo de segredos da ferramenta de CI/CD.
- Procedimento documentado para gerar e trocar chaves e senhas.

---

### US-06: Migrações e carga inicial do banco
**Prioridade:** Must

**Como** equipe do projeto,
**quero** que o banco seja criado e atualizado automaticamente,
**para** recriar o ambiente de forma reproduzível.

**Critérios de aceite:**
- Migrações executadas automaticamente na subida do ambiente e no deploy.
- Carga inicial (*seed*) com o primeiro administrador, o local e o terminal de demonstração, sem credenciais fixas no código.
- Dados de demonstração separados dos de produção.
- Documentado como recriar o banco do zero.

---

### US-07: Pipeline de CI do backend
**Prioridade:** Must

**Como** equipe do projeto,
**quero** que cada commit do backend seja construído, analisado e testado automaticamente,
**para** detectar falhas cedo (RNF08, RP09).

**Critérios de aceite:**
- Execução a cada commit e pull request, na ferramenta escolhida (por exemplo, GitHub Actions ou GitLab CI).
- Etapas: instalação, build, verificação de tipos, lint e testes automatizados.
- Testes de integração rodando com um banco de teste PostgreSQL e MQTT simulado.
- Falha em qualquer etapa bloqueia o merge.
- Pipeline sem testes não é aceitável: a execução dos testes é obrigatória (RP10, RNF10).

---

### US-08: Pipeline de CI do frontend
**Prioridade:** Must

**Como** equipe do projeto,
**quero** que cada commit do frontend seja verificado automaticamente,
**para** manter a qualidade e a coerência de tipos (RNF08).

**Critérios de aceite:**
- Etapas: instalação, verificação de tipos, lint (ESLint), testes (Vitest) e build.
- Teste ponta a ponta (Playwright) executado no pipeline ou em uma etapa dedicada.
- Falha em qualquer etapa bloqueia o merge.

---

### US-09: Pipeline de CI dos aplicativos Flutter
**Prioridade:** Must

**Como** equipe do projeto,
**quero** que os três apps Flutter sejam verificados a cada commit,
**para** manter a qualidade dos aplicativos (RNF08).

**Critérios de aceite:**
- Para mobile-registry, mobile-readings e mobile-user: `flutter analyze`, `flutter test` e build do APK.
- Pipeline compartilhado ou parametrizado entre os três apps, evitando duplicação.
- Pacote Dart interno comum incluído nas verificações.
- Falha em qualquer etapa bloqueia o merge.

---

### US-10: Pipeline de CI do firmware
**Prioridade:** Should

**Como** equipe do projeto,
**quero** que o firmware do ESP32 seja compilado e testado a cada commit,
**para** garantir que o código continue compilando (RNF08).

**Critérios de aceite:**
- Execução de `pio run` e `pio test` a cada commit.
- Compilação funcionando com `config.example.h`, já que `config.h` não é versionado.
- Falha em qualquer etapa bloqueia o merge.

---

### US-11: Geração e distribuição do APK
**Prioridade:** Should

**Como** participante da apresentação,
**quero** baixar o APK de cada app pelo repositório,
**para** instalar nos aparelhos sem compilar localmente.

**Critérios de aceite:**
- O pipeline gera o APK de cada app e o disponibiliza como artefato do repositório.
- Nome do arquivo identifica o app e a versão.
- Documentado como instalar o APK, incluindo permitir a instalação de fontes desconhecidas no Android.
- O APK não contém segredos embutidos.

---

### US-12: CD: publicação das imagens Docker
**Prioridade:** Must

**Como** equipe do projeto,
**quero** que as imagens sejam publicadas automaticamente após a CI aprovada,
**para** ter artefatos prontos para implantação (RNF09).

**Critérios de aceite:**
- Após CI aprovada na branch principal, as imagens do backend e do frontend são construídas e enviadas a um registro de imagens.
- Imagens com *tag* de versão e do commit, rastreáveis ao código de origem.
- Publicação não ocorre se alguma etapa da CI falhar.

---

### US-13: CD: deploy automatizado do backend
**Prioridade:** Must

**Como** equipe do projeto,
**quero** que o backend seja implantado automaticamente em um ambiente de homologação ou na nuvem,
**para** cumprir o requisito de deploy automatizado (RNF09, RP11).

**Critérios de aceite:**
- Provedor de nuvem ou ambiente de homologação escolhido e documentado.
- Deploy disparado automaticamente após a publicação das imagens, sem passos manuais.
- Migrações executadas no deploy, com verificação de saúde (`GET /health`) ao final.
- Procedimento de reversão documentado em caso de falha.

---

### US-14: Banco de dados em nuvem
**Prioridade:** Should

**Como** equipe do projeto,
**quero** provisionar uma instância PostgreSQL em nuvem,
**para** atender ao requisito de persistência em nuvem (RNF06).

**Critérios de aceite:**
- Instância PostgreSQL em nuvem criada e usada pelo ambiente de deploy.
- O ambiente local de demonstração continua usando o PostgreSQL do Compose, e a configuração alterna entre os dois por variável de ambiente.
- Acesso protegido por credenciais e restrição de origem.
- Decisão alinhada com o professor e registrada na documentação.

---

### US-15: Feedback do pipeline
**Prioridade:** Should

**Como** equipe do projeto,
**quero** ver claramente o resultado de cada build, teste e deploy,
**para** corrigir falhas rapidamente (RNF12).

**Critérios de aceite:**
- Status das execuções visível no próprio repositório (por exemplo, selos no README e checagens nos pull requests).
- Logs das etapas acessíveis e legíveis.
- Notificação de falha no canal da equipe (e-mail ou mensagens).
- Relatório de testes publicado como resultado da execução.

---

### US-16: Rede e ambiente da demonstração
**Prioridade:** Must

**Como** equipe do projeto,
**quero** preparar a rede local da apresentação,
**para** que todos os dispositivos se comuniquem sem depender de internet.

**Critérios de aceite:**
- Roteador ou hotspot próprio configurado com banda 2.4 GHz para o ESP32, e notebook com IP fixo na LAN.
- Backend, broker e frontend alcançáveis por todos os dispositivos (celulares, ESP32 e notebook), com portas liberadas no firewall.
- Orientação para manter o Wi-Fi ativo e desativar dados móveis nos celulares, evitando que migrem de rede.
- Script ou roteiro de verificação rápida do ambiente (subida do Compose, saúde da API, conexão do broker).
- Teste completo realizado com os aparelhos reais antes da apresentação.

---

### US-17: Servidor de horário local
**Prioridade:** Could

**Como** equipe do projeto,
**quero** um servidor NTP local na rede de demonstração,
**para** que o ESP32 tenha horário correto sem internet.

**Critérios de aceite:**
- Servidor NTP executando no notebook ou em um container, acessível na LAN.
- ESP32 configurado para sincronizar com esse servidor.
- Dispensável caso o firmware adote validade relativa dos comandos, e a decisão fica registrada.

---

### US-18: Backup e persistência de dados
**Prioridade:** Should

**Como** equipe do projeto,
**quero** salvaguardar banco e fotos,
**para** não perder dados ao recriar o ambiente.

**Critérios de aceite:**
- Rotina de backup do banco incluindo o volume de `/photos`, executável por script.
- Procedimento de restauração testado.
- Documentado que o volume não é replicado, o que é aceitável na demonstração e deve constar como limitação.

---

### US-19: Monitoramento e logs
**Prioridade:** Should

**Como** equipe do projeto,
**quero** acompanhar a saúde e os logs dos serviços,
**para** depurar rapidamente durante a demonstração (RNF03, RNF12).

**Critérios de aceite:**
- Logs estruturados do backend acessíveis por comando simples (por exemplo, `docker compose logs`).
- Estado dos serviços verificável pelos healthchecks do Compose.
- Alerta de queda do ESP32, aproveitando o Last Will, visível no backend.
- Rotação de logs para não encher o disco.

---

### US-20: HTTPS e MQTT seguro opcionais
**Prioridade:** Could

**Como** administrador do sistema,
**quero** a opção de usar TLS nas comunicações,
**para** aproximar o sistema de um cenário real (RNF02).

**Critérios de aceite:**
- HTTPS no Nginx com certificado autoassinado ou de uma autoridade, quando houver domínio.
- TLS no Mosquitto, com o ESP32 e o mobile-readings configurados para usá-lo.
- Documentadas as consequências para a demonstração, como a validação de certificados nos aparelhos.
- Se não for implementado, a ausência de TLS na LAN fica declarada como limitação.

---

## Pontos para sua decisão sobre este épico

- **Ferramenta de CI/CD e organização dos repositórios:** o desafio permite GitHub Actions, GitLab CI, Azure DevOps ou similares, e o docx não escolhe. A US-01 e a US-07 deixam essa decisão como critério de aceite.
- **Provedor de nuvem:** o desafio prefere o deploy do backend em nuvem, mas o docx não define o provedor. A decisão está na US-13.
- **Banco em nuvem (RNF06):** o requisito pede banco em nuvem, e o docx sugere manter o PostgreSQL local para a demonstração e provisionar uma instância em nuvem no CD, apresentando as duas. Isso precisa ser alinhado com o professor (US-14).
- **Testes são obrigatórios:** o desafio não aceita projeto sem execução automatizada de testes integrada ao pipeline (RP10). Por isso as CIs do backend, frontend e apps Flutter são **Must**, e a do firmware ficou como **Should**.
- **TLS:** o docx aceita HTTP e MQTT sem TLS na LAN de demonstração, desde que declarado como limitação. Por isso a US-20 ficou como **Could**.

---

# Épico 8: docs/SCRUM

**Descrição:** organização do trabalho da equipe em Scrum e documentação técnica do projeto. Reúne os papéis, as cerimônias, a gestão do backlog e o acompanhamento do desenvolvimento incremental (RP06), além da documentação exigida em RP07: arquitetura, diagramas e descrição da comunicação entre os elementos. Também concentra o registro de riscos, as limitações assumidas e os materiais de uso e de apresentação.

**Requisitos relacionados:** RNF05, RNF11, RP06, RP07, RP08

---

### US-01: Papéis e cerimônias do Scrum
**Prioridade:** Must

**Como** equipe do projeto,
**quero** definir quem exerce cada papel e como serão as cerimônias,
**para** trabalhar de forma organizada e previsível.

**Critérios de aceite:**
- Papéis definidos: Product Owner, Scrum Master e time de desenvolvimento, com os responsáveis nomeados.
- Cerimônias e horários combinados: planejamento, acompanhamento diário, review e retrospectiva.
- Responsáveis por cada serviço (mobile-registry, mobile-readings, mobile-user, device-esp32, backend, frontend e DevOps) identificados.
- Combinados registrados em um documento acessível a toda a equipe.

---

### US-02: Refinamento e priorização do backlog
**Prioridade:** Must

**Como** Product Owner,
**quero** manter o product backlog refinado e priorizado,
**para** que o time sempre trabalhe no que tem mais valor.

**Critérios de aceite:**
- Backlog revisado periodicamente, com stories novas, ajustadas ou removidas conforme as decisões do grupo.
- Prioridade (Must, Should ou Could) revisada após cada review.
- Stories grandes divididas até caberem em uma sprint.
- Estimativas de esforço atribuídas às stories antes do planejamento.

---

### US-03: Definition of Ready e Definition of Done
**Prioridade:** Must

**Como** equipe do projeto,
**quero** critérios comuns para dizer quando uma story está pronta para começar e quando está concluída,
**para** evitar entregas incompletas.

**Critérios de aceite:**
- Definition of Ready acordada (por exemplo, critérios de aceite claros e dependências conhecidas).
- Definition of Done acordada, incluindo código revisado, testes automatizados passando no pipeline, documentação atualizada e funcionamento demonstrável.
- Ambos os documentos visíveis no quadro da equipe e aplicados no planejamento e na review.

---

### US-04: Planejamento de sprint
**Prioridade:** Must

**Como** equipe do projeto,
**quero** planejar cada sprint com meta e itens escolhidos,
**para** entregar incrementos funcionais (RP06).

**Critérios de aceite:**
- Cada sprint tem meta clara e um sprint backlog com as stories selecionadas.
- Capacidade do time considerada, com base na disponibilidade dos integrantes e no que foi entregue nas sprints anteriores.
- Dependências entre serviços consideradas na escolha (por exemplo, backend e simulador do ESP32 antes da integração dos apps).
- Resultado do planejamento registrado.

---

### US-05: Quadro de tarefas e rastreabilidade
**Prioridade:** Must

**Como** equipe do projeto,
**quero** um quadro com as stories e suas tarefas,
**para** ver o andamento e relacionar o trabalho ao código.

**Critérios de aceite:**
- Ferramenta de gestão escolhida (por exemplo, GitHub Projects, Trello ou Jira) e backlog importado.
- Colunas definidas, como A fazer, Em andamento, Em revisão e Concluído.
- Branches e pull requests referenciam o identificador da story.
- Cada serviço pode ser filtrado no quadro por épico.

---

### US-06: Acompanhamento do progresso
**Prioridade:** Should

**Como** Scrum Master,
**quero** acompanhar o progresso da sprint,
**para** identificar atrasos e impedimentos cedo.

**Critérios de aceite:**
- Reunião diária curta, ou registro assíncrono equivalente, com o que foi feito, o que será feito e impedimentos.
- Impedimentos registrados e tratados com responsável.
- Indicador de progresso da sprint (por exemplo, burndown) atualizado.
- Velocidade do time registrada ao final de cada sprint.

---

### US-07: Sprint Review e entregas parciais
**Prioridade:** Must

**Como** equipe do projeto,
**quero** apresentar um incremento funcional ao final de cada sprint,
**para** cumprir o desenvolvimento incremental e receber feedback (RP06).

**Critérios de aceite:**
- Roteiro de demonstração preparado para cada Sprint Review do cronograma do desafio.
- Ambiente de demonstração verificado antes da apresentação.
- Feedback recebido registrado e convertido em stories ou ajustes no backlog.
- Itens não concluídos justificados e reavaliados.

---

### US-08: Retrospectiva
**Prioridade:** Should

**Como** equipe do projeto,
**quero** refletir sobre o que funcionou e o que pode melhorar,
**para** evoluir o processo a cada sprint.

**Critérios de aceite:**
- Retrospectiva realizada ao fim de cada sprint, com registro do que foi bem, do que foi mal e das melhorias.
- No máximo poucas ações de melhoria por sprint, com responsável.
- Ações revisadas na retrospectiva seguinte.

---

### US-09: Registro de riscos e decisões em aberto
**Prioridade:** Must

**Como** equipe do projeto,
**quero** manter um registro único de riscos e decisões pendentes,
**para** não perder pontos importantes levantados em cada serviço.

**Critérios de aceite:**
- Registro consolidando os riscos e as decisões em aberto de todos os serviços, com responsável e situação.
- Decisões tomadas registradas com data e justificativa.
- Riscos mais prováveis na demonstração, como Wi-Fi sem internet, alimentação da trava e GPS em ambiente fechado, acompanhados com ações de mitigação.
- Registro revisado em cada planejamento de sprint.

---

### US-10: Esclarecimento de requisitos com o professor
**Prioridade:** Must

**Como** equipe do projeto,
**quero** levar as ambiguidades do desafio ao professor,
**para** evitar entregar algo que não atenda ao que se espera.

**Critérios de aceite:**
- Lista de dúvidas elaborada: raio de proximidade de 100 metros (pelo menos ou no máximo), banco em nuvem (RNF06), leitor NFC no ESP32 e não no terminal (já decidido pelo professor), e quem administra locais e autorizações (aplicativo móvel ou frontend).
- Respostas registradas e refletidas nos requisitos e no backlog.
- Itens ainda em aberto mantidos no registro de decisões.

---

### US-11: Documentação da arquitetura
**Prioridade:** Must

**Como** equipe do projeto,
**quero** documentar a arquitetura da solução,
**para** cumprir RP07 e ajudar novos integrantes e avaliadores a entenderem o sistema.

**Critérios de aceite:**
- Desenho da arquitetura distribuída com os seis serviços (mobile-readings, mobile-registry, backend, device-esp32, frontend e mobile-user) e a separação entre dispositivo, backend e aplicativos (RP05).
- Descrição do papel de cada serviço e das tecnologias utilizadas.
- Infraestrutura descrita: Docker Compose com backend, Mosquitto, PostgreSQL e frontend em notebook na LAN.
- Decisões de arquitetura registradas com justificativa (por exemplo, rodar em LAN sem depender de internet).

---

### US-12: Diagramas de casos de uso
**Prioridade:** Must

**Como** equipe do projeto,
**quero** os diagramas de casos de uso do sistema,
**para** cumprir RP07 e mostrar como cada perfil interage com o sistema.

**Critérios de aceite:**
- Casos de uso dos atores: administrador, condômino, visitante e terminal de acesso.
- Casos cobrindo cadastro, autorizações, acesso por QR Code e NFC, histórico e dashboard.
- Reconhecimento facial identificado como caso opcional.
- Diagramas versionados no repositório, em formato editável.

---

### US-13: Diagramas de componentes e de sequência
**Prioridade:** Must

**Como** equipe do projeto,
**quero** diagramas de componentes e de sequência dos fluxos principais,
**para** documentar como os serviços colaboram (RP07).

**Critérios de aceite:**
- Diagrama de componentes mostrando os serviços, o broker e o banco.
- Diagramas de sequência para os fluxos de acesso por QR Code, por NFC, por reconhecimento facial e de detecção de presença.
- Fluxo de cadastro (usuário, tag e rosto) também documentado.
- Diagramas versionados no repositório, em formato editável.

---

### US-14: Documentação da comunicação entre os elementos
**Prioridade:** Must

**Como** equipe do projeto,
**quero** descrever os protocolos, os endpoints e os tópicos usados entre os serviços,
**para** cumprir RP07 e evitar divergências de contrato entre os clientes.

**Critérios de aceite:**
- Mapa de comunicação: apps e backend por HTTP/REST, backend e ESP32 por MQTT, mobile-readings e broker por MQTT para presença.
- Tabela de tópicos MQTT (`command`, `presence`, `status` e `ack`) com sentido, payload e QoS.
- Referência à especificação OpenAPI do backend para os endpoints.
- Comportamentos descritos: reconexão, idempotência de comandos, validade do comando e Last Will.

---

### US-15: Documentação do modelo de dados
**Prioridade:** Should

**Como** equipe do projeto,
**quero** documentar o banco de dados,
**para** que todos compreendam as entidades e suas relações.

**Critérios de aceite:**
- Diagrama entidade-relacionamento das tabelas do backend.
- Dicionário com os campos principais de cada entidade.
- Observações sobre dados sensíveis (embedding, foto, senha) e como são tratados.

---

### US-16: Matriz de rastreabilidade de requisitos
**Prioridade:** Should

**Como** equipe do projeto,
**quero** relacionar cada requisito do desafio ao serviço e às stories que o atendem,
**para** demonstrar a cobertura de todos os requisitos.

**Critérios de aceite:**
- Matriz cobrindo os requisitos funcionais (RF01 a RF17), não funcionais (RNF01 a RNF12) e as restrições de projeto (RP01 a RP12).
- Cada requisito aponta para o serviço e as user stories que o atendem.
- Requisitos atendidos parcialmente ou por simulação destacados, como o GPS do terminal (RP08).
- Matriz atualizada ao final de cada sprint.

---

### US-17: Documentação de segurança, limitações e LGPD
**Prioridade:** Must

**Como** equipe do projeto,
**quero** documentar as medidas de segurança e as limitações assumidas,
**para** apresentar o sistema com transparência sobre o que ele cobre.

**Critérios de aceite:**
- Medidas de segurança resumidas por serviço, incluindo autenticação, ACL do broker, QR de uso único e proteção dos dados biométricos.
- Limitações declaradas: HTTP e MQTT sem TLS na LAN, ausência de detecção de vivacidade no reconhecimento facial, falsificação de localização, volume de fotos sem replicação e confiança no resultado facial do terminal.
- Decisão fail-secure ou fail-safe da trava registrada.
- Tratamento de dados biométricos descrito em relação à LGPD: consentimento, exclusão e finalidade.

---

### US-18: README e manual de instalação e execução
**Prioridade:** Must

**Como** equipe do projeto,
**quero** documentação clara de como instalar, configurar e executar cada parte,
**para** que qualquer pessoa consiga subir o sistema.

**Critérios de aceite:**
- README em cada repositório ou serviço, com descrição, pré-requisitos, configuração e comandos.
- Guia de subida do ambiente completo com Docker Compose.
- Guia de montagem e ligação do hardware do ESP32, com esquema elétrico.
- Guia de instalação do APK e de configuração do endereço do servidor nos apps.
- Procedimento de execução do simulador do dispositivo.

---

### US-19: Guia de uso dos aplicativos
**Prioridade:** Could

**Como** usuário,
**quero** um guia simples de como usar os aplicativos,
**para** aprender o fluxo sem ajuda, inclusive sendo idoso.

**Critérios de aceite:**
- Guia ilustrado e em linguagem simples, para o mobile-user (entrar, abrir a porta e ver autorizações).
- Guia para o administrador, com o cadastro de usuário, tag e rosto, e com a criação de autorizações.
- Instruções para o que fazer em caso de acesso negado ou falha de rede.

---

### US-20: Roteiro e ensaio da apresentação final
**Prioridade:** Must

**Como** equipe do projeto,
**quero** um roteiro ensaiado da apresentação final,
**para** demonstrar o sistema com segurança, mesmo diante de falhas.

**Critérios de aceite:**
- Roteiro cobrindo o cenário do desafio: usuário autorizado liberado por QR Code e por NFC, e acesso negado com registro do evento.
- Plano B definido, como o simulador do dispositivo (RP08), documentado e testado.
- Ensaio completo realizado com os aparelhos reais e a rede da demonstração.
- Papéis de cada integrante na apresentação definidos.

---

## Pontos para sua decisão sobre este épico

- **Papéis do Scrum:** o docx não define quem é Product Owner e Scrum Master. A decisão cabe ao grupo e está na US-01.
- **Ferramenta de gestão:** o backlog foi escrito em Markdown, mas o acompanhamento diário exige uma ferramenta de quadro. A escolha está na US-05.
- **Sprints no backlog:** conforme sua instrução, nenhum épico ou story indica em qual sprint será feito. O planejamento por sprint fica por conta da US-04.
- **Dúvidas para o professor:** a US-10 reúne as ambiguidades levantadas ao longo dos épicos (raio de 100 metros, banco em nuvem, divisão do Terminal de Acesso e quem administra autorizações).