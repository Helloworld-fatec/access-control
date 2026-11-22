# Registro de riscos e decisões em aberto

Origem: `docs/access-control-visao-geral.docx`, PDF do desafio e imagens de arquitetura.
"Dono" é quem leva o tema adiante, não necessariamente quem decide. Os donos dos riscos seguem a divisão de responsáveis por serviço. As decisões abaixo estão detalhadas, com a proposta do grupo, em [PAUTA-PROFESSOR.md](./PAUTA-PROFESSOR.md).

## Decisões a levar ao professor (US-10)

| ID | Decisão | Por que importa | Dono | Status |
|---|---|---|---|---|
| D1 | Reconhecimento facial é obrigatório ou extra? | A imagem de arquitetura diz "obrigatória"; o docx e o PDF tratam como extra | Suelen | o time segue com o facial como extra; confirmar com o professor na Review 3 |
| D2 | Raio de proximidade: "pelo menos 100 m" (PDF) ou "no máximo 100 m" (docx)? | Define a regra de validação do QR (RF13) | Suelen | aberto |
| D3 | Banco e deploy em nuvem (RNF06, RP11) com demonstração em LAN: aceitável ter os dois? | Entrega final roda local com Docker (decisão do PO); backend já publicado em nuvem no desenvolvimento | Suelen / Bruno | aberto |
| D4 | Locais e autorizações só no frontend: aceito, ou o mobile-registry precisa dessas telas? | O desafio descreve a administração como função do app móvel | Suelen | aberto |
| D5 | Leitura de NFC: celular ou leitor ligado ao ESP32? | Definido pelo professor: leitor no ESP32 (Arduino). O mesmo ESP32 grava a tag com um código gerado pelo backend (definição do PO). Arquitetura atualizada | Suelen | resolvido |
| D6 | Login do visitante: senha temporária ou convite? | Afeta mobile-registry, mobile-user e backend | Suelen | aberto |
| D7 | Fechadura: fail-secure ou fail-safe? | Comportamento sem energia; declarar a escolha | Suelen / Bruna | aberto |

## Riscos técnicos e de projeto

| ID | Risco | Mitigação | Dono | Status |
|---|---|---|---|---|
| R1 | Wi-Fi da apresentação sem internet ou instável | Roteador/hotspot próprio, testar com aparelhos reais, avisar sobre dados móveis | Bruno | aberto |
| R2 | Contrato da API muda e quebra os três clientes | Publicar especificação OpenAPI versionada. Hoje as rotas estão descritas em [`docs/api.md`](../docs/api.md), sem OpenAPI | Bruno / Pedro | aberto |
| R3 | Embeddings faciais incompatíveis entre mobile-registry e mobile-readings | Pacote Dart comum para extração | Ryan / Nicolas | aberto |
| R4 | Código duplicado entre os três apps Flutter | Pacote Dart interno compartilhado | Ryan / Nicolas / Bruno | aberto |
| R5 | Sem pipeline de CI com testes o projeto não é aceito (RP10) | Pipeline mínimo (build, lint, testes). Em 22/11 a `main` só tem o workflow do mobile-registry, cujos últimos runs falharam no passo `flutter build apk`. A branch `feat/estrutura` (Bruno) traz 6 workflows (backend, frontend, três apps e ESP32), ainda não mesclados | Bruno / Suelen | em andamento |
| R6 | Alimentação da trava e HC-SR04 instáveis na bancada | Fonte separada, diodo de flyback, testar antes de integrar | Bruna | aberto |
| R7 | Precisão do GPS em ambiente fechado | Enviar `accuracy`, calibrar raio no local | Bruno | aberto |
| R8 | Escopo grande (cerca de 170 histórias) para 3 sprints | Priorizar Must por sprint, adiar Could | Suelen | aberto |
| R9 | Dado biométrico (LGPD): embedding e foto são dados sensíveis | Consentimento registrado, coluna separada, exclusão prevista | Backend / Registry | aberto |
| R10 | Integração do leitor e gravador NFC (RC522 ou PN532) com o ESP32: ligação SPI ou I2C em 3,3 V | Testar na bancada cedo; ACL nos tópicos `nfc` e `enroll` | Bruna / Bruno | aberto |
| R11 | Tipo de tag incompatível com gravação, ou gravação que falha ou corrompe o código | Escolher tag com memória gravável (NTAG ou MIFARE), ler de volta para conferir e permitir repetir o pedido | Bruna | aberto |
| R12 | Um único ESP32 lê e grava: durante a gravação o acesso por NFC fica indisponível por alguns segundos | Janela de gravação curta, com tempo limite; acesso por QR segue funcionando | Bruna / Bruno | aberto |
| R13 | O escopo do device-esp32 aumentou (leitor, gravador e publicação do código) | Priorizar a leitura e o comando de abertura; gravação em seguida; simulador MQTT como plano B | Bruna / Suelen | aberto |
| R14 | Tag copiada com o código dentro seria aceita como a original | Revogar a tag no backend; avaliar conferir também o UID | Bruno | aberto |
| R15 | O leitor RC522 do terminal físico tem possível falha na soldagem | Levar a avaliação ao professor; manter o teste isolado que funcionou e o firmware com a leitura desativada até a revisão | Bruna / Suelen | aberto |
| R16 | A compilação do mobile-registry é extremamente lenta e atrasa os testes | Investigar como reduzir o tempo de compilação e relatar na daily | Ryan | aberto |
| R17 | O contrato MQTT v1 já é usado pelo mobile-readings e foi implementado no backend na branch `feat/estrutura`, ainda não mesclada; na `main` o backend simula a publicação | Validar o contrato em reunião e implementar a publicação no backend e o consumo no firmware. A branch `feat/estrutura` já traz a dependência MQTT e um simulador, ainda não mesclados | Bruno / Bruna / Nicolas | em andamento |
| R18 | O acesso por QR não valida a proximidade e usa dois formatos de token | Unificar o QR, enviar a localização do app e calcular a distância no backend | Bruno | aberto |
| R19 | As rotas de usuários, locais e histórico não exigem login | Exigir o JWT de administrador nessas rotas | Bruno / Pedro | aberto |
| R20 | O QR exibido no OLED ainda não é lido direto pela câmera do celular | Ajustar o QR Code do display e testar com mais de um aparelho | Bruna | aberto |
| R21 | A `develop` está 26 commits à frente da `main` e a `feat/estrutura` está 26 commits atrás da `develop`: o código da Sprint 3 pode chegar à `main` tarde ou com conflitos | Mesclar na ordem `feat/estrutura` na `develop`, depois `develop` na `main`, até 23/11, e conferir os pipelines. Fluxo em [`CONTRIBUTING.md`](../CONTRIBUTING.md) | Bruno / Suelen | aberto |
