# device-esp32

Terminal físico do access-control, construído com **ESP32**. Detecta a aproximação de uma pessoa, exibe o QR Code em um display OLED, lê a tag NFC (leitor RC522), sinaliza o resultado com LEDs e buzzer e aciona um microservo que representa o trinco. O dispositivo não decide o acesso: no sistema final, ele só executa o comando recebido do backend.

Responsável: Bruna. Todo o conteúdo técnico está em [`hardware/`](./hardware).

## Onde encontrar

| O que | Onde |
|---|---|
| Situação atual, componentes, pinagem, como rodar e limitações | [`hardware/README.md`](./hardware/README.md) |
| Firmware para a montagem física | [`hardware/firmware/`](./hardware/firmware) |
| Testes de cada componente (buzzer, infravermelho, LEDs, OLED, RC522 e servo) | [`hardware/testes/`](./hardware/testes) |
| Simulação no Wokwi | [`hardware/simulacao/wokwi/`](./hardware/simulacao/wokwi) |
| Contrato das mensagens MQTT com o backend | [`../docs/contrato-mqtt.md`](../docs/contrato-mqtt.md) |

## Situação na Sprint 2

- Sensor infravermelho, OLED com QR Code, LEDs, buzzer e microservo testados separadamente e em conjunto na bancada, com a autorização simulada pelo monitor serial.
- O QR Code no display foi reconhecido a partir de uma fotografia, e a leitura direta pelo celular ainda precisa de ajuste.
- O leitor RC522 passou em teste isolado, mas a integração física aguarda revisão de solda.
- O GPS ainda não foi testado, e o terminal ainda não conversa com o backend.

## Próxima sprint

Revisar e integrar o RC522, testar o GPS, integrar ao backend por MQTT, montar o suporte físico (maquete) e ajustar o QR Code para a leitura direta pelo celular.
