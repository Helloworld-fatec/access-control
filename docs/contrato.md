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
| `qr/request` | ESP32 → backend | 1 | Não |
| `qr/display` | Backend → ESP32 | 1 | Não |

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

Leia o UID físico de **4, 7 ou 10 bytes** e publique `uid` em hexadecimal maiúsculo sem separadores, preservando zeros à esquerda. O administrador vincula o UID ao usuário pelo painel ou mobile-registry, usando `POST /api/users/{id}/tags` com `{"uid":"04A32F1B"}`. A memória da tag permanece intacta. O backend consulta a tag ativa em `nfc_tags`, valida a autorização do usuário para o local da placa e grava a decisão. O backend descarta pedidos recebidos depois de **5 s** da leitura. O firmware aguarda até **5 s** pelo resultado e mantém a porta fechada se o prazo terminar. Enquanto houver uma tag no campo, trate a leitura como uma única apresentação.

```json
{
  "schemaVersion": 1,
  "terminalId": "df96f695-a94c-4a4d-9ac5-f90beca3cd71",
  "eventId": "5b1e029e-a24c-4322-a20c-61fc42542d47",
  "requestId": "a1a84eb7-ba8f-4e29-bb6a-a373ad0bcda0",
  "uid": "04A32F1B",
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

## QR do OLED e QR do celular

O OLED solicita um QR em `qr/request` com o envelope comum, `occurredAt` e um novo `requestId` após 3 s de presença confirmada. O backend aceita pedidos recentes da placa configurada. Em `qr/display`, responde com o envelope, o mesmo `requestId`, `expiresAt` (20 s após a emissão), `refreshAfterSeconds: 10` e `bitmap`. O bitmap tem 112 caracteres hexadecimais que representam 56 bytes. Os 441 módulos de um QR versão 1 ocupam os bits em ordem de linha da esquerda para a direita, começando pelo bit mais significativo de cada byte. Um bit 1 representa um módulo escuro. Os sete bits finais ficam em zero.

O ESP32 aceita apenas uma resposta que corresponda ao pedido pendente. Aplica escala de 2 pixels por módulo e margem de 4 módulos, totalizando 58 × 58 pixels no OLED de 128 × 64. O OLED deixa de mostrar o código quando a presença termina, quando a conexão é perdida ou quando o código expira. A renovação usa um novo pedido enquanto houver presença.

O QR do OLED codifica um token de 20 caracteres alfanuméricos maiúsculos com prefixo `Q`. O QR do mobile-readings continua usando o JSON `{"v":1,"token":"..."}` emitido por `POST /api/terminals/me/qr`. O usuário abre o leitor de QR do mobile-user e escaneia qualquer um dos dois. O app envia o token extraído para `POST /api/access/qr/consume` com o JWT do usuário. Ambos os tokens expiram e são de uso único. Uma concessão válida gera `door/command` com `method: "QR"`.

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

O prazo de 5 s limita o **aceite** da ordem. A placa valida a ordem antes de `expiresAt` e registra `acceptedAt` em UTC. Se puder atuar, registra a tentativa de forma persistente antes de mover o motor. O prazo inicial de bancada para concluir os passos de abertura e datar o ACK é de **10 s após `acceptedAt`**. O backend verifica as duas janelas separadamente. O horário do ACK pode ultrapassar `expiresAt`.

A placa devolve o `requestId` e o `accessLogId` da ordem. Use `UNLOCKED` ao concluir os passos comandados de abertura. Esse resultado confirma o acionamento, enquanto `door/state` é reservado à posição observada por sensor. A duração de `unlockDurationMs` começa ao terminar a abertura. No sketch são 3000 ms, seguidos de fechamento automático sob controle local.

Use `ERROR` se uma ordem válida não puder ser executada ou se a tentativa falhar. Se já houver um ciclo em andamento, registre `acceptedAt` como o instante de avaliação da ordem válida, devolva `ERROR` e mantenha o ciclo em andamento. Use `EXPIRED` opcionalmente para uma ordem vencida, sem `acceptedAt` e com `occurredAt` entre `expiresAt` e 10 s após o vencimento. Uma negativa NFC encerra a espera e dispensa ACK. O primeiro ACK válido encerra a confirmação no backend. Em QR e face, o backend preserva o resultado específico do ACK. Em NFC, o histórico registra sucesso, falha ou confirmação pendente.

Uma repetição conserva o ACK e seus horários originais. Após reinício, se a placa já registrou uma tentativa mas perdeu o resultado, não repete a atuação. O sketch atual assume posição inicial fechada e a recuperação da posição deve ser validada em bancada.

```json
{
  "schemaVersion": 1,
  "terminalId": "df96f695-a94c-4a4d-9ac5-f90beca3cd71",
  "eventId": "8b1e029e-a24c-4322-a20c-61fc42542d47",
  "requestId": "a1a84eb7-ba8f-4e29-bb6a-a373ad0bcda0",
  "accessLogId": "01e13323-bb93-4c82-8e35-06c7e62704fc",
  "result": "UNLOCKED",
  "acceptedAt": "2026-11-23T12:00:04Z",
  "occurredAt": "2026-11-23T12:00:09.120Z"
}
```

## Gravação legada no simulador

Os tópicos abaixo são exclusivos do simulador quando ele estiver configurado. Eles mantêm a compatibilidade com o ensaio legado. O cadastro e a autorização por UID independem desse ensaio.

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
- O firmware executa no máximo uma vez por `requestId`. Deve registrar a tentativa antes de acionar, conservar essa informação até o vencimento mesmo se reiniciar e, ao reconhecer uma repetição, poder reenviar o resultado conhecido. Na dúvida sobre uma execução após reinício, não repetir a ação.
- A placa sincroniza o relógio por NTP/SNTP antes de aceitar comandos temporizados e também usa um relógio monotônico para aguardar a decisão NFC. Com relógio indisponível, mantém a porta fechada. O backend descarta eventos de telemetria fora de ordem e mensagens operacionais vencidas.
- Em desconexão, o ESP32 tenta novamente após **1 s**, aumentando o intervalo progressivamente até **30 s**. Ao reconectar, refaz as assinaturas e publica heartbeat e estados atuais. Use sessão limpa para a placa e descarte ordens expiradas mesmo após reconexão.
- Limite o acesso aos tópicos que transportam o UID. O UID identifica a tag cadastrada e pode ser copiado em alguns tipos de cartão.

## Pontos para validar no hardware

Validar TLS e QoS 1 pela LAN, sincronização de horário, leitura dos UIDs das tags reais, remoção da tag antes do rearme e deduplicação após reinício. Confirmar o comportamento do motor e do sensor durante o ciclo.
