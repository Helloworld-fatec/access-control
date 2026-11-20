# Contrato MQTT entre ESP32, terminal de leitura e backend

> **RASCUNHO PARA DISCUSSÃO:** este contrato precisa ser validado em reunião com as equipes de backend, firmware e terminal de leitura. Tópicos, campos e regras podem ser alterados após essa validação.

## 1. Objetivo e participantes

O sistema é composto por serviços independentes que trocam mensagens por um broker MQTT:

- **ESP32:** detecta a aproximação, lê a credencial e controla a fechadura; informa o estado físico da porta.
- **Terminal de leitura:** recebe o aviso de aproximação e inicia a experiência de leitura/apresentação da credencial.
- **Backend:** valida a credencial e as regras de acesso; envia ao ESP32 a decisão de liberar ou negar a passagem.
- **Broker MQTT:** encaminha as mensagens entre os participantes.

Cada ESP32 e terminal deve ter um `terminalId` estável, provisionado pelo backend. Os exemplos abaixo usam `terminal-001`; em produção, substituir pelo identificador cadastrado.

## 2. Convenções

- Payloads codificados em UTF-8 e serializados como JSON.
- `eventId` identifica uma mensagem; `requestId` correlaciona uma leitura com sua decisão.
- Datas e horários usam ISO 8601 em UTC, por exemplo `2026-11-08T19:08:42.292Z`.
- O campo `schemaVersion` permite evoluir o contrato sem ambiguidades.
- O ESP32 deve tratar mensagens duplicadas de forma idempotente, usando `eventId` ou `requestId`.

## 3. Tópicos e direção

| Tópico | Publicador → assinante | Finalidade | QoS sugerido |
|---|---|---|---:|
| `access/v1/terminals/{terminalId}/presence` | ESP32 → terminal de leitura | Avisar que alguém se aproximou | 1 |
| `access/v1/terminals/{terminalId}/door/state` | ESP32 → backend | Informar porta aberta ou fechada | 1 |
| `access/v1/terminals/{terminalId}/access/request` | ESP32 → backend | Solicitar validação de credencial | 1 |
| `access/v1/terminals/{terminalId}/access/decision` | Backend → ESP32 | Autorizar ou negar a passagem | 1 |

O broker deve aplicar ACL por identidade: o ESP32 publica presença, estado e solicitações apenas para seu próprio `terminalId`; o backend publica decisões; o terminal de leitura assina apenas o tópico de presença do terminal associado.

## 4. Mensagens

### 4.1 Aviso de aproximação

O ESP32 publica quando o sensor detecta uma pessoa dentro da faixa configurada. Para evitar notificações repetidas, o firmware deve aplicar debounce e só emitir novo evento após a pessoa deixar a área de detecção ou após uma janela definida.

**Tópico:** `access/v1/terminals/{terminalId}/presence`

```json
{
  "schemaVersion": 1,
  "eventId": "01J9PRESENCE7K2M4N6Q8R0S1T3V5",
  "terminalId": "terminal-001",
  "detected": true,
  "distanceCm": 82.4,
  "occurredAt": "2026-11-08T19:08:42.292Z"
}
```

O terminal de leitura usa `detected: true` para sair do repouso e preparar a tela/leitor. Um evento com `detected: false` pode indicar que a área ficou livre e permitir que o terminal retorne ao repouso.

### 4.2 Estado físico da porta

O ESP32 publica sempre que o sensor de porta indicar uma mudança de estado. O backend registra o estado mais recente e pode detectar porta aberta por tempo excessivo.

**Tópico:** `access/v1/terminals/{terminalId}/door/state`

```json
{
  "schemaVersion": 1,
  "eventId": "01J9DOOR9K2M4N6Q8R0S1T3V5A7",
  "terminalId": "terminal-001",
  "state": "OPEN",
  "occurredAt": "2026-11-08T19:08:44.010Z"
}
```

Valores permitidos para `state`: `OPEN` e `CLOSED`. Mensagens retidas (*retained*) não são necessárias para eventos de mudança; o estado atual também pode ser enviado em uma mensagem periódica de presença do dispositivo, se isso for decidido na reunião.

### 4.3 Pedido de decisão de acesso

Após ler uma credencial, o ESP32 envia o identificador/código da credencial ao backend e aguarda a resposta correlacionada. O segredo ou conteúdo da credencial deve ser protegido em trânsito e não deve conter dados pessoais desnecessários.

**Tópico:** `access/v1/terminals/{terminalId}/access/request`

```json
{
  "schemaVersion": 1,
  "eventId": "01J9REQUEST7K2M4N6Q8R0S1T3V5A9",
  "requestId": "01J9ACCESS7K2M4N6Q8R0S1T3V5B1",
  "terminalId": "terminal-001",
  "credential": {
    "type": "NFC",
    "value": "credencial-opaca-gerada-pelo-backend"
  },
  "occurredAt": "2026-11-08T19:08:45.100Z"
}
```

`credential.type` identifica o método, por exemplo `NFC`. O campo `value` representa o código opaco apresentado; a forma de transportar QR ou reconhecimento facial deve ser especificada quando esses fluxos forem fechados.

### 4.4 Decisão do backend

O backend valida credencial, usuário, autorização, validade, horário, limite de usos e demais regras aplicáveis. Publica exatamente uma decisão correlacionada ao pedido. O ESP32 só aciona a fechadura quando recebe `authorized: true` para um pedido válido e ainda não expirado.

**Tópico:** `access/v1/terminals/{terminalId}/access/decision`

```json
{
  "schemaVersion": 1,
  "eventId": "01J9DECISION7K2M4N6Q8R0S1T3V5C3",
  "requestId": "01J9ACCESS7K2M4N6Q8R0S1T3V5B1",
  "terminalId": "terminal-001",
  "authorized": true,
  "reason": null,
  "unlockDurationMs": 3000,
  "expiresAt": "2026-11-08T19:08:50.000Z",
  "decidedAt": "2026-11-08T19:08:45.350Z"
}
```

Exemplo de negação:

```json
{
  "schemaVersion": 1,
  "eventId": "01J9DENY7K2M4N6Q8R0S1T3V5C5",
  "requestId": "01J9ACCESS7K2M4N6Q8R0S1T3V5B1",
  "terminalId": "terminal-001",
  "authorized": false,
  "reason": "NO_AUTHORIZATION",
  "unlockDurationMs": 0,
  "expiresAt": "2026-11-08T19:08:50.000Z",
  "decidedAt": "2026-11-08T19:08:45.350Z"
}
```

O backend é a autoridade da decisão. Se a resposta não chegar antes do timeout, estiver expirada, tiver `requestId` desconhecido ou já tiver sido processada, o ESP32 mantém a porta travada e nega por padrão. A duração solicitada não pode exceder o limite máximo configurado no firmware.

## 5. Confirmações, disponibilidade e segurança

- Usar QoS 1 para solicitações e decisões; consumidores devem aceitar entrega duplicada sem repetir a ação física.
- O ESP32 deve publicar uma confirmação de execução da decisão, incluindo `requestId`, resultado (`UNLOCKED`, `DENIED` ou `ERROR`) e horário. O tópico final dessa confirmação precisa ser acordado na reunião.
- Configurar `clientId` exclusivo por dispositivo, autenticação individual, TLS e ACL por tópico no broker.
- Comandos de decisão não devem ser retidos (*retained*), para que uma autorização antiga não seja aplicada após reconexão.
- Definir na reunião os timeouts, frequência de heartbeat, retenção de eventos, limites de payload e política de reconexão.
- Registrar no backend os pedidos, decisões, eventos de porta e confirmações necessários para auditoria.

## 6. Fluxo resumido

1. O ESP32 detecta aproximação e publica `presence`; o terminal de leitura ativa sua interface.
2. O ESP32 lê a credencial e publica `access/request`.
3. O backend valida a credencial e publica `access/decision` com o mesmo `requestId`.
4. O ESP32 libera a fechadura apenas se a decisão for positiva, válida e dentro do prazo; depois publica a confirmação.
5. O sensor informa mudanças da porta em `door/state`, e o backend mantém o estado registrado.
