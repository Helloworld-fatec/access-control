# Registro de riscos e decisões em aberto

Origem: `docs/access-control-visao-geral.docx`, PDF do desafio e imagens de arquitetura.
"Dono" é quem leva o tema adiante, não necessariamente quem decide. Os donos dos riscos seguem a divisão de responsáveis por serviço. As decisões abaixo estão detalhadas, com a proposta do grupo, em [PAUTA-PROFESSOR.md](./PAUTA-PROFESSOR.md).

## Decisões a levar ao professor (US-10)

| ID | Decisão | Por que importa | Dono | Status |
|---|---|---|---|---|
| D1 | Reconhecimento facial é obrigatório ou extra? | A imagem de arquitetura diz "obrigatória"; o docx e o PDF tratam como extra | Suelen | aberto |
| D2 | Raio de proximidade: "pelo menos 100 m" (PDF) ou "no máximo 100 m" (docx)? | Define a regra de validação do QR (RF13) | Suelen | aberto |
| D3 | Banco e deploy em nuvem (RNF06, RP11) com demonstração em LAN: aceitável ter os dois? | Entrega final roda local com Docker (decisão do PO); backend já publicado em nuvem no desenvolvimento | Suelen / Bruno | aberto |
| D4 | Locais e autorizações só no frontend: aceito, ou o mobile-registry precisa dessas telas? | O desafio descreve a administração como função do app móvel | Suelen | aberto |
| D5 | Leitura de NFC: celular ou leitor ligado ao ESP32? | Definido pelo professor: leitor no ESP32 (Arduino). Arquitetura e cadastro de tags atualizados | Suelen | resolvido |
| D6 | Login do visitante: senha temporária ou convite? | Afeta mobile-registry, mobile-user e backend | Suelen | aberto |
| D7 | Fechadura: fail-secure ou fail-safe? | Comportamento sem energia; declarar a escolha | Suelen / Bruna | aberto |

## Riscos técnicos e de projeto

| ID | Risco | Mitigação | Dono | Status |
|---|---|---|---|---|
| R1 | Wi-Fi da apresentação sem internet ou instável | Roteador/hotspot próprio, testar com aparelhos reais, avisar sobre dados móveis | Bruno | aberto |
| R2 | Contrato da API muda e quebra os três clientes | Publicar especificação OpenAPI versionada | Bruno / Pedro | aberto |
| R3 | Embeddings faciais incompatíveis entre mobile-registry e mobile-readings | Pacote Dart comum para extração | Ryan / Nick | aberto |
| R4 | Código duplicado entre os três apps Flutter | Pacote Dart interno compartilhado | Ryan / Nick / Bruno | aberto |
| R5 | Sem pipeline de CI com testes o projeto não é aceito (RP10) | Pipeline mínimo (build, lint, testes) já na Sprint 1 | Bruno | aberto |
| R6 | Alimentação da trava e HC-SR04 instáveis na bancada | Fonte separada, diodo de flyback, testar antes de integrar | Bruna | aberto |
| R7 | Precisão do GPS em ambiente fechado | Enviar `accuracy`, calibrar raio no local | Bruno | aberto |
| R8 | Escopo grande (cerca de 166 histórias) para 3 sprints | Priorizar Must por sprint, adiar Could | Suelen | aberto |
| R9 | Dado biométrico (LGPD): embedding e foto são dados sensíveis | Consentimento registrado, coluna separada, exclusão prevista | Backend / Registry | aberto |
| R10 | Integração do leitor NFC (RC522 ou PN532) com o ESP32: ligação SPI ou I2C em 3,3 V e formato do UID | Testar na bancada cedo; padronizar o UID em hexadecimal maiúsculo no firmware e no backend; ACL no tópico `nfc` | Bruna / Bruno | aberto |
| R11 | O escopo do device-esp32 aumentou (leitor NFC e cadastro de tags) | Priorizar a leitura do UID e o comando de abertura; cadastro de tag depois; simulador MQTT como plano B | Bruna / Suelen | aberto |
