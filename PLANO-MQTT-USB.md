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
