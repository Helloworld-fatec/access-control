# mobile-readings — Terminal de Acesso

Aplicativo Flutter que desempenha o papel de **Terminal de Acesso** ([Épico 2 do Backlog](../scrum/BACKLOG.md)). Permanece fixo junto à entrada/catraca, exibe o QR Code rotativo, realiza a leitura de tags NFC e encaminha as credenciais ao `backend` para validação.

> **Regra de Arquitetura:** O terminal **nunca decide** a liberação por conta própria. Ele coleta a credencial e encaminha ao `backend`, operando em modo *fail-closed* (qualquer indisponibilidade de rede resulta em negação segura).

---

## Funcionalidades Implementadas

- **Estrutura Modular em Camadas (`US-01`):**
  - `lib/config/`: modelo e persistência de configurações (`shared_preferences` + `flutter_secure_storage`).
  - `lib/models/`: modelos de resposta (`AccessResult`, `QrToken`, `TerminalStatus`).
  - `lib/services/`: cliente HTTP com retry (`TerminalApiClient`), leitor NFC (`NativeNfcReaderService`), cliente MQTT (`MosquittoPresenceService`) e sincronização de embeddings em memória (`FaceSyncService`).
  - `lib/state/`: máquina de estados (`TerminalController`).
  - `lib/screens/`: tela principal do terminal (`TerminalScreen`) e tela de configurações (`SettingsScreen`).
- **Configuração em Tempo de Execução (`US-02`):**
  - Configuração de IP/porta do backend, IP/porta/credenciais do broker MQTT, `terminalId`, `apiKey` do terminal, tempo de inatividade e limiar facial, além de **Modo de Simulação (Mock Local)** para testes sem hardware externo.
- **Cliente HTTP com Autenticação do Terminal e Retry (`US-03`, `US-12`):**
  - Envio de `x-api-key` e `Authorization: Bearer <apiKey>`.
  - Retry automático em falhas de rede/timeout e comportamento *fail-closed* sem cache de autorizações.
- **Máquina de Estados e Economia de Energia (`US-04`, `US-13`, `US-14`):**
  - Estados: `Repouso` (`idle`), `Escuta` (`listening`), `Validando` (`validating`), `Liberado` (`granted`) e `Negado` (`denied`).
  - Leitor NFC e renovação do QR Code ficam ativos **somente** no estado de `Escuta`.
- **Detecção de Presença via MQTT + Fallback HTTP (`US-05`, `US-06`):**
  - Assinatura do tópico `terminal/{id}/presence` no broker Mosquitto (porta TCP `1883`).
  - Fallback automático consultando `GET /api/terminals/{id}/status` quando o MQTT estiver desconectado.
- **QR Code Rotativo e Invalidação Segura (`US-07`, `US-08`):**
  - Renovação a cada 10 segundos em `GET /api/terminals/{id}/qr`.
  - Remoção imediata do QR Code e aviso `"QR indisponível"` em caso de falha de comunicação.
- **Leitura e Envio de Tag NFC (`US-09`, `US-10`):**
  - Extração do UID via API nativa Android, padronizado em hexadecimal maiúsculo sem separadores (ex.: `04A1B2C3`).
  - *Cooldown* (intervalo mínimo de 3s) entre leituras para evitar registros duplicados em `POST /api/access/nfc`.
- **Feedback Visual Acessível (`US-11`, `US-20`):**
  - Telas de alto contraste combinando cor, ícone e texto simples (`Acesso liberado` / `Acesso negado` / `Sistema indisponível`).

---

## Integrações (Contratos)

| Protocolo | Rota / Tópico | Descrição |
|---|---|---|
| **MQTT** | `terminal/{id}/presence` | Recebe evento de presença publicado pelo `device-esp32` |
| **HTTP GET** | `/api/terminals/{id}/status` | Fallback de presença por polling quando MQTT está offline |
| **HTTP GET** | `/api/terminals/{id}/qr` | Obtém token assinado do QR Code rotativo a cada 10s |
| **HTTP POST** | `/api/access/nfc` | Envia `{ terminalId, uid }` para validação de tag NFC |
| **HTTP GET** | `/api/terminals/{id}/faces` | Sincroniza embeddings autorizados (apenas em memória RAM) |
| **HTTP POST** | `/api/access/face` | Envia `{ terminalId, userId, confidence }` (reconhecimento facial) |

---

## Como Executar

```bash
cd mobile-readings
flutter pub get
flutter run
```

### Executar Análise Estática e Testes Automatizados (`US-21`)

```bash
flutter analyze
flutter test
```
