# Ponte USB do ESP32 para o Mosquitto

Execute a ponte no **Windows**, com Node.js 20 ou superior. O ESP32 usa o cabo USB e o broker usa MQTT com TLS em `127.0.0.1:8883`.

## Preparar no PowerShell

Na raiz do projeto, execute:

```powershell
Set-Location device-esp32/usb-bridge
npm.cmd ci
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
wsl.exe -d Ubuntu -- docker exec access-control-mosquitto-1 cat /mqtt-ca/ca.crt |
  Set-Content -Encoding Ascii mqtt-ca.crt
```

Se o contêiner tiver outro nome, use o nome exibido por `docker compose ps mosquitto` no WSL. No `.env` da ponte, use o mesmo `ESP32_TERMINAL_ID` configurado no firmware e no broker, e a mesma `MQTT_ESP32_PASSWORD` configurada no broker. Preserve a grafia do UUID. O arquivo `.env` e a cópia da CA ficam fora do Git.

## Executar

Depois de gravar o firmware USB, feche o Monitor Serial do Arduino IDE para liberar a COM4. Na pasta da ponte, execute:

```powershell
npm.cmd start
```

A execução mostra `[MQTT] TLS conectado e assinaturas QoS 1 confirmadas.` quando o broker estiver pronto e `[USB] Sessão serial pronta.` após o handshake com o ESP32. A placa registra `[USB] Ponte MQTT pronta.` quando ambos os lados estiverem operacionais. Os logs do ESP32 aparecem no mesmo console. Use **Ctrl+C** para parar a ponte e liberar a COM4 antes de outro upload.

O formato dos quadros e os tópicos estão no [plano de integração](../../PLANO-MQTT-USB.md#passo-3--protocolo-serial-versão-1).
