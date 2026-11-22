# Contrato MQTT v1 do ESP32

Este contrato define a interface para a demonstração. O backend valida os acessos, e o ESP32 lê e grava tags, publica eventos físicos e aciona a fechadura. O mobile-readings consulta a API HTTP com seu próprio terminal. O firmware novo ainda precisa confirmar o armazenamento físico da tag e os sinais que a placa consegue medir.

## Identidade e transporte

Cadastre a placa no formulário atual com o nome **ESP 32** e configure o UUID gerado em `ESP32_TERMINAL_ID` no backend e como `terminalId` no firmware. Todos os exemplos usam `df96f695-a94c-4a4d-9ac5-f90beca3cd71` como UUID da placa. O backend confere o UUID do tópico, o campo da mensagem e o terminal configurado. As tentativas NFC ficam no histórico com o UUID da placa. Os acessos originados por QR ou reconhecimento facial mantêm o UUID do terminal de origem, com o comando enviado à placa do mesmo local.

Cada cliente usa um `clientId` próprio e autentica na conexão com o Mosquitto. Configure TLS com verificação do certificado, conexão anônima desativada e ACL por identidade. A placa publica somente nos tópicos ESP32 → backend do próprio UUID e assina apenas os tópicos de resposta, abertura e gravação desse UUID. A conta do backend tem as permissões correspondentes. O simulador usa conta e UUID de teste. O payload contém a identidade da placa e os dados da operação. A senha fica na conexão com o broker.

## Tópicos e formato

Prefixo comum: `access/v1/terminals/{terminalId}/`. Cada payload é um objeto JSON em UTF-8 de até **2 KiB**, com `schemaVersion: 1`, `terminalId` e `eventId` (UUID). Horários são UTC em ISO 8601 com sufixo `Z`. Mensagens correlacionadas também incluem `requestId` (UUID). O originador gera um novo `requestId` por operação. Toda repetição da mesma publicação conserva seus IDs. Uma resposta ou confirmação tem seu próprio `eventId` e repete o `requestId` da operação.

| Sufixo | Publicador → assinante | QoS | Retido |
| --- | --- | ---: | --- |
| `status` | ESP32 → backend | 1 | Não |
| `presence` | ESP32 → backend | 1 | Não |
| `door/state` | ESP32 → backend | 1 | Não |
| `access/request` | ESP32 → backend | 1 | Não |
| `access/decision` | Backend → ESP32 | 1 | Não |
| `door/command` | Backend → ESP32 | 1 | Não |
| `door/ack` | ESP32 → backend | 1 | Não |
| `nfc/enroll` | Backend → ESP32 | 1 | Não |
| `nfc/enroll/ack` | ESP32 → backend | 1 | Não |

## Estado da placa e da porta

### `status`

Publique ao conectar e depois a cada **10 s**. O backend considera a placa indisponível após **30 s** sem heartbeat válido. A publicação informa o instante de emissão. O backend descarta estados antigos e usa o horário de recebimento de uma mensagem válida para atualizar a disponibilidade.

```json
{
  "schemaVersion": 1,
  "terminalId": "df96f695-a94c-4a4d-9ac5-f90beca3cd71",
  "eventId": "2b1e029e-a24c-4322-a20c-61fc42542d47",
  "occurredAt": "2026-11-23T12:00:00Z"
}
```

### `presence`

Publique na mudança de detecção e renove `detected: true` a cada **2 s** enquanto houver alguém na área. O backend expira a presença em **5 s** sem renovação. O ESP32 deve filtrar oscilações do sensor. `distanceCm` é opcional e, quando presente, contém um número finito não negativo. Um evento atrasado ou duplicado não renova o prazo de presença.

```json
{
  "schemaVersion": 1,
  "terminalId": "df96f695-a94c-4a4d-9ac5-f90beca3cd71",
  "eventId": "3b1e029e-a24c-4322-a20c-61fc42542d47",
  "detected": true,
  "distanceCm": 82.4,
  "occurredAt": "2026-11-23T12:00:01Z"
}
```

### `door/state`

Se houver sensor físico, publique o estado após conectar e a cada mudança. Valores: `OPEN` e `CLOSED`. O backend mantém o estado observado mais recente. Uma confirmação de acionamento da fechadura não substitui a leitura desse sensor.

```json
{
  "schemaVersion": 1,
  "terminalId": "df96f695-a94c-4a4d-9ac5-f90beca3cd71",
  "eventId": "4b1e029e-a24c-4322-a20c-61fc42542d47",
  "state": "OPEN",
  "occurredAt": "2026-11-23T12:00:05Z"
}
```

## Acesso por NFC

### `access/request`

Leia os bytes da credencial gravada e publique `credential.value` com **seis dígitos hexadecimais maiúsculos**, incluindo zeros à esquerda. O código identifica a credencial cadastrada em `nfc_credentials`. O backend exige que ela esteja ativa, valida a autorização para o local da placa e grava a decisão. O backend descarta pedidos recebidos depois de **5 s** da leitura. O firmware aguarda até **5 s** pelo resultado e mantém a fechadura travada se o prazo terminar. Enquanto a mesma tag permanecer no campo, trate a leitura como uma única apresentação.

```json
{
  "schemaVersion": 1,
  "terminalId": "df96f695-a94c-4a4d-9ac5-f90beca3cd71",
  "eventId": "5b1e029e-a24c-4322-a20c-61fc42542d47",
  "requestId": "a1a84eb7-ba8f-4e29-bb6a-a373ad0bcda0",
  "credential": { "type": "NFC", "value": "00A3F9" },
  "occurredAt": "2026-11-23T12:00:02Z"
}
```

### `access/decision`

O backend responde com o mesmo `requestId` e com o `accessLogId` gravado. A placa só executa uma concessão enquanto houver um pedido NFC correspondente em aberto, dentro do timeout local e antes de `expiresAt`. O backend limita `expiresAt` ao prazo da solicitação. Na negativa, `authorized` é `false`, `reason` contém o código da decisão (por exemplo, `NO_AUTHORIZATION`) e `unlockDurationMs` é `0`.

```json
{
  "schemaVersion": 1,
  "terminalId": "df96f695-a94c-4a4d-9ac5-f90beca3cd71",
  "eventId": "6b1e029e-a24c-4322-a20c-61fc42542d47",
  "requestId": "a1a84eb7-ba8f-4e29-bb6a-a373ad0bcda0",
  "accessLogId": "01e13323-bb93-4c82-8e35-06c7e62704fc",
  "authorized": true,
  "reason": null,
  "unlockDurationMs": 3000,
  "decidedAt": "2026-11-23T12:00:03Z",
  "expiresAt": "2026-11-23T12:00:07Z"
}
```

## Abertura iniciada por QR ou reconhecimento facial

### `door/command`

O backend publica após gravar a concessão do QR ou após reconhecer a pessoa em `POST /api/access/face/capture`. Use o mesmo valor em `requestId` e `accessLogId` nos comandos emitidos pelo backend. A placa pode executar esse comando sem um pedido NFC pendente. Valide o UUID do destino, a expiração, o identificador e a duração. Para a demonstração, o comando vence **5 s** após a concessão e a duração máxima é **3000 ms**. O mesmo limite de duração vale para `access/decision`. Uma concessão registrada só indica execução física após o `door/ack`.

```json
{
  "schemaVersion": 1,
  "terminalId": "df96f695-a94c-4a4d-9ac5-f90beca3cd71",
  "eventId": "7b1e029e-a24c-4322-a20c-61fc42542d47",
  "requestId": "02e13323-bb93-4c82-8e35-06c7e62704fc",
  "accessLogId": "02e13323-bb93-4c82-8e35-06c7e62704fc",
  "method": "QR",
  "unlockDurationMs": 3000,
  "occurredAt": "2026-11-23T12:01:00Z",
  "expiresAt": "2026-11-23T12:01:05Z"
}
```

Use `method: "FACE"` para reconhecimento facial.

### `door/ack`

Após tentar executar uma concessão NFC ou um comando de abertura, a placa devolve o `requestId` e o `accessLogId` recebidos. Use `UNLOCKED` quando o acionamento for executado e `ERROR` quando a execução falhar. Um comando vencido pode retornar `EXPIRED`. Uma decisão NFC negada encerra a espera no firmware e já está registrada no backend. O backend valida a correlação com a concessão ou comando enviado àquela placa. Apenas `UNLOCKED` marca a abertura como confirmada.

```json
{
  "schemaVersion": 1,
  "terminalId": "df96f695-a94c-4a4d-9ac5-f90beca3cd71",
  "eventId": "8b1e029e-a24c-4322-a20c-61fc42542d47",
  "requestId": "a1a84eb7-ba8f-4e29-bb6a-a373ad0bcda0",
  "accessLogId": "01e13323-bb93-4c82-8e35-06c7e62704fc",
  "result": "UNLOCKED",
  "occurredAt": "2026-11-23T12:00:04Z"
}
```

## Gravação da tag NFC

### `nfc/enroll`

O frontend ou mobile-registry solicita a gravação com `POST /api/users/{id}/nfc-enrollments`. O corpo pode conter `expectedUid`. A API retorna `202` com o `id`, o estado e o prazo. Os clientes acompanham o pedido com `GET /api/users/{id}/nfc-enrollments/{requestId}`. A operação exige autenticação de administrador.

O backend registra a tentativa pendente e publica o pedido para o UUID configurado. Pode reutilizar um código pendente que ainda não foi enviado para gravação. Depois de falha ou expiração, uma nova tentativa usa outro código, pois a tag anterior pode ter sido gravada sem confirmação. O pedido vale por **30 s** e só pode haver uma gravação em andamento por leitor. Para substituir uma tag ativa, remova a associação anterior.

`credentialHex` usa o mesmo formato de seis dígitos do pedido de acesso. A representação proposta para a tag é a sequência de três bytes decodificados na ordem do hex, por exemplo `00 A3 F9`. A equipe de firmware precisa confirmar o tipo da tag, a área gravável e a releitura. Se o UID da tag já tiver sido capturado durante o cadastro, envie `expectedUid` no formato hexadecimal normalizado, sem separadores. A placa confere esse UID antes de gravar. Quando o campo estiver ausente, a operação vale para a primeira tag apresentada localmente durante a janela.

```json
{
  "schemaVersion": 1,
  "terminalId": "df96f695-a94c-4a4d-9ac5-f90beca3cd71",
  "eventId": "9b1e029e-a24c-4322-a20c-61fc42542d47",
  "requestId": "c1a84eb7-ba8f-4e29-bb6a-a373ad0bcda0",
  "credentialHex": "00A3F9",
  "expectedUid": "04A32F1B",
  "occurredAt": "2026-11-23T11:59:20Z",
  "expiresAt": "2026-11-23T11:59:50Z"
}
```

### `nfc/enroll/ack`

A placa grava, relê a mesma tag e compara os bytes. Só publique `WRITTEN` se a comparação for bem-sucedida. Nesse resultado inclua o `uid` e `readbackSha256`, o SHA-256 dos **três bytes relidos**, em hex minúsculo de 64 dígitos. Para `FAILED` ou `TIMEOUT`, omita esse hash e inclua `reason`, por exemplo `WRITE_FAILED`, `READBACK_MISMATCH`, `UID_MISMATCH` ou `TAG_NOT_PRESENT`. O backend valida a placa, o pedido pendente, o prazo, a releitura e o UID esperado, se houver. A credencial só é ativada após a confirmação válida.

```json
{
  "schemaVersion": 1,
  "terminalId": "df96f695-a94c-4a4d-9ac5-f90beca3cd71",
  "eventId": "ab1e029e-a24c-4322-a20c-61fc42542d47",
  "requestId": "c1a84eb7-ba8f-4e29-bb6a-a373ad0bcda0",
  "result": "WRITTEN",
  "uid": "04A32F1B",
  "readbackSha256": "5a2665c693e7b42fc3624e0a25a4bce1d0ce9daf75de33d57aca69c9b546877d",
  "occurredAt": "2026-11-23T11:59:24Z"
}
```

## Duplicatas, expiração e reconexão

- O backend deve persistir a decisão NFC por par `(terminalId, requestId)` junto do registro de acesso, de forma atômica com a contagem de uso. Uma repetição recebe a decisão original enquanto o pedido ainda for válido. O backend ignora a reutilização do mesmo identificador com dados diferentes. Confirmações repetidas não criam novas concessões ou ativações.
- O firmware executa no máximo uma vez por `requestId`. Deve registrar a execução ou a tentativa antes de acionar ou gravar, conservar essa informação até o vencimento mesmo se reiniciar e, ao reconhecer uma repetição, poder reenviar o resultado conhecido. Na dúvida sobre uma execução após reinício, não repetir a ação.
- A placa sincroniza o relógio por NTP/SNTP antes de aceitar comandos temporizados e também usa um relógio monotônico para aguardar a decisão NFC. Com relógio indisponível, mantém a porta travada e suspende gravações. O backend descarta eventos de telemetria fora de ordem e mensagens operacionais vencidas.
- Em desconexão, o ESP32 tenta novamente após **1 s**, aumentando o intervalo progressivamente até **30 s**. Ao reconectar, refaz as assinaturas e publica heartbeat e estados atuais. Use sessão limpa para a placa e descarte ordens expiradas mesmo após reconexão.
- Limite o acesso aos tópicos que transportam o código NFC e evite gravar payloads com esse código em logs. O código de seis dígitos segue o esquema existente da demonstração e pode ser copiado de uma tag. O hash de releitura verifica a consistência da gravação, sem autenticar a tag.

## Pontos para validar no hardware

Confirmar biblioteca MQTT com TLS e publicação QoS 1, sincronização de horário em LAN, área de armazenamento da tag e releitura dos três bytes. Confirmar quais sensores existem, como o firmware identifica uma execução da fechadura e se consegue preservar a deduplicação após reinício. Até a integração com a placa, o simulador deve reproduzir o contrato. A persistência dos pedidos, a ponte com o broker e a confirmação de gravação serão implementadas nas próximas etapas.
