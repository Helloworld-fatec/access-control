# Plano de integração do ESP32 por USB com o Mosquitto no WSL

## Objetivo

Usar o cabo USB já ligado à COM4 para integrar o ESP32 ao sistema de acesso. O firmware troca mensagens por serial com uma ponte executada no Windows. A ponte publica e recebe mensagens MQTT via TLS no Mosquitto, que continua rodando no Docker dentro do WSL junto com o backend.

```text
ESP32  ← USB serial / COM4 →  Ponte no Windows  ← MQTT/TLS →  Mosquitto no WSL
                                                                     ↕
                                                               Backend no WSL
```

## Passo a passo

1. **Validar o firmware e a serial.** Usar a COM4 a 115200 e observar o boot após apertar EN. Confirmar que o firmware chega ao `setup()`. Testar a leitura do sensor no GPIO 27 aproximando e afastando um objeto. Se houver `csum err` antes de `[BOOT]`, resolver a inicialização antes de testar a ponte.
2. **Validar o caminho do Windows até o broker.** No WSL, conferir a porta publicada do Mosquitto com `docker compose ps mosquitto`. No PowerShell, testar `Test-NetConnection 127.0.0.1 -Port 8883`, usando a porta publicada real. Se falhar, conferir o modo de rede do WSL e a publicação da porta antes de alterar o firmware. Manter o acesso restrito ao host. O nome ou IP usado pela ponte precisa constar no certificado do broker, e a ponte precisa confiar na CA exportada pelo Mosquitto.
3. **Definir o protocolo serial.** Usar JSON delimitado por nova linha, com tipo de quadro e versão. Definir quadros para handshake, estado da conexão, envio e recebimento de mensagens e diagnóstico. Limitar o tamanho dos quadros, tratar linhas incompletas após reset e correlacionar confirmações com o identificador da mensagem. Isolar os logs dos quadros de dados, já que ambos passam pela COM4.
4. **Adaptar o firmware em `device-esp32/sketch-final`.** Separar o transporte da lógica em `mqtt_porta.cpp` e implementar a opção serial. Manter no ESP32 a validação de terminal, mensagens e prazos, os registros persistentes e o controle do motor. Sincronizar o relógio da placa com a ponte no handshake e exigir nova sincronização após reset. Fazer a leitura e a escrita seriais sem bloquear o loop do motor.
5. **Criar a ponte para Windows.** Abrir a COM4 com o Monitor Serial fechado e autenticar no broker com a conta `esp32` e o UUID configurado para esse terminal. Carregar a porta, endereço, CA e senha de configuração local. Traduzir os quadros seriais para os mesmos tópicos e payloads usados hoje, com QoS 1 e publicações sem retenção. Restringir o encaminhamento aos tópicos do terminal e confirmar as assinaturas antes de indicar que a ponte está operacional.
6. **Tratar quedas e retomadas.** Quando cair o USB ou o MQTT, informar a perda da sessão quando possível, invalidar solicitações pendentes e impedir novas aberturas até restabelecer a sessão. Um movimento em andamento segue a lógica existente de fechamento e recuperação. Após reconectar, refazer handshake e assinaturas, verificar os prazos e preservar a deduplicação de comandos. Distinguir a confirmação de recebimento serial, a confirmação de publicação MQTT e o ACK de execução da porta.
7. **Validar de ponta a ponta.** Primeiro verificar se o broker registra a ponte e se o backend recebe `status` e `presence`. Depois validar solicitação e exibição de QR, leitura NFC e decisão do backend. Por último, validar um ciclo de abertura e fechamento em bancada e conferir o ACK. Repetir com reset do ESP32, desconexão do USB e reinício do broker. Confirmar que um comando vencido ou duplicado não aciona a porta novamente.

## Critério de conclusão

Com o Wi-Fi do ESP32 desativado, o Windows comunica com a placa pela COM4 e mantém a sessão MQTT/TLS com o Mosquitto no WSL. O backend recebe presença, processa QR e NFC e recebe a confirmação de execução da porta. Após uma queda, a comunicação volta sem executar comandos vencidos ou duplicados.

## Passo 3 · Protocolo serial versão 1

### Formato

- **COM4, 115200 baud, 8N1**, sem controle de fluxo. A ponte tem acesso exclusivo à porta durante o teste.
- Cada quadro começa com `@AC `, contém um objeto JSON UTF-8 em uma linha e termina em LF. O leitor também aceita CRLF. Linhas sem esse prefixo são saída de diagnóstico e podem ser exibidas no console da ponte.
- O quadro tem até **3.072 bytes**, contando o prefixo e excluindo a quebra de linha. O campo `payload` é um objeto JSON de até **2.048 bytes** quando serializado de forma compacta. Ao exceder o limite ou receber uma linha inválida, o receptor descarta a linha e retoma na próxima quebra. A recepção deve aceitar quadros divididos entre várias leituras e vários quadros na mesma leitura.
- Todos os quadros têm `v: 1` e `type`. Depois do handshake, cada quadro inclui `sessionId`, um UUID gerado pelo Windows para aquela sessão serial. Os dois lados descartam mensagens com versão, tipo ou sessão inválidos. Quadros de controle com campos inválidos também são descartados.

### Sessão e relógio

| Quadro | Origem | Campos e efeito |
| --- | --- | --- |
| `hello` | ESP32 | Envia `terminalId` e `bootId`, um UUID novo após cada reset. Repete a cada segundo enquanto aguarda seleção de sessão. |
| `welcome` | Windows | Devolve `terminalId` e `bootId`, atribui `sessionId` e envia `utcMs`, um inteiro em milissegundos desde a época Unix. A placa confere os identificadores e sincroniza o relógio. |
| `ready` | ESP32 | Confirma o `sessionId` após ajustar o relógio. Um `welcome` repetido para a mesma sessão pode receber outro `ready`. |
| `link` | Windows | Envia `mqttReady: true\|false` ao mudar de estado e, enquanto a serial estiver ativa, a cada 1 segundo. Só informa `true` depois de conectar com TLS e confirmar as três assinaturas com QoS 1. |
| `heartbeat` | ESP32 | Envia um quadro a cada 1 segundo enquanto a sessão estiver ativa. |

O dispositivo só aceita quadros de dados com a sessão ativa, o relógio sincronizado e `mqttReady: true`. Após **3 segundos** sem receber `link` ou `heartbeat`, o lado correspondente invalida a sessão. USB desconectado ou novo `bootId` também invalidam a sessão. Se o MQTT cair com a serial ativa, a ponte envia `link` com `mqttReady: false`. Na retomada, envia um novo `welcome` com o mesmo `bootId` e outro `sessionId`, repetindo-o até receber `ready`. A placa aceita a troca de sessão quando o MQTT está indisponível ou quando aguarda o handshake inicial. A ponte só informa `mqttReady: true` após receber `ready` e confirmar as assinaturas. A placa limpa solicitações e mensagens pendentes da sessão anterior e preserva os registros persistentes e a lógica de um ciclo da porta em andamento.

### Dados e confirmações

| Quadro | Origem | Campos e efeito |
| --- | --- | --- |
| `publish` | ESP32 | `id`, `route`, `payload`. Solicita à ponte uma publicação MQTT com QoS 1 e sem retenção. |
| `deliver` | Windows | `id`, `route`, `payload`. Encaminha uma mensagem MQTT recebida com QoS 1 e sem retenção. A placa valida o conteúdo antes de enfileirar. |
| `ack` | Ambos | `id`, `forType` (`publish` ou `deliver`) e `result`. O Windows responde `published` depois do PUBACK MQTT. A placa responde `accepted` depois de validar e enfileirar. Em falha, o receptor responde `rejected` com `reason` (`invalid`, `unavailable`, `queue_full` ou `mqtt_error`). |

O `id` é um inteiro positivo de 32 bits, crescente por emissor dentro da sessão. A serial mantém a ordem. Um quadro com ID já processado é descartado sem novo encaminhamento. Se a confirmação se perder, o emissor encerra a espera após **3 segundos**. A ponte não reenvia quadros após reconexão. A recuperação dos ACKs persistidos e a deduplicação por `requestId` continuam sob responsabilidade do firmware. `accepted` confirma somente a entrada do quadro na fila. A confirmação da abertura continua sendo a mensagem MQTT `door/ack` com o resultado da execução.

### Tópicos permitidos

A ponte monta ou valida o tópico completo sob `access/v1/terminals/<terminalId>/`, usando o UUID do terminal configurado e conferido no handshake. Confere também o `terminalId` do payload. O protocolo serial carrega apenas o sufixo em `route`.

| Direção | Valores permitidos em `route` |
| --- | --- |
| ESP32 → MQTT | `status`, `presence`, `access/request`, `qr/request`, `door/ack` |
| MQTT → ESP32 | `access/decision`, `qr/display`, `door/command` |

### Validação para a implementação

- Testar handshake com broker disponível e indisponível, relógio inválido, terminal divergente e reconexão após reset.
- Testar leitura fragmentada, múltiplas linhas, logs de boot entre quadros, JSON inválido, quadro acima do limite e recuperação na próxima linha.
- Testar sessão antiga, ID duplicado, rota fora da lista, payload de outro terminal, fila cheia e confirmação perdida.
- Confirmar que um comando vencido ou repetido não aciona o motor e que `door/ack` corresponde à execução, mesmo após reconexão.
