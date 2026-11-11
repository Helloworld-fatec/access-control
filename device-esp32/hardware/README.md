# Hardware — Sistema Integrado de Controle de Acesso

Protótipo acadêmico de controle de acesso com ESP32, identificação por RFID e QR Code, detecção de aproximação e acionamento de um microservo que representa o trinco.

Este diretório reúne os códigos de teste dos componentes, o firmware integrado destinado à montagem física e a simulação no Wokwi.

## Situação atual

Na Sprint 2, os componentes foram testados separadamente e depois em conjunto, com autorização simulada. O protótipo ainda não está integrado ao backend ou ao broker MQTT.

| Recurso | Situação |
| --- | --- |
| ESP32, LEDs, buzzer, microservo e sensor infravermelho | Testados fisicamente de forma individual e integrada |
| OLED | Exibição de mensagens e QR Code testada fisicamente |
| Leitura do QR Code físico | Conteúdo reconhecido a partir de uma fotografia; leitura direta pelo celular ainda precisa de ajuste |
| RC522 | Leitura realizada em teste isolado; revisão de solda e validação da integração física pendentes |
| Fluxo completo com autorização local por UID | Validado no Wokwi |
| GPS | Apenas coordenadas fixas de demonstração no código do Wokwi; módulo físico ainda não testado |
| Backend/MQTT | Integração prevista para a próxima sprint |

A simulação não valida as condições elétricas da montagem física.

## Organização dos arquivos

Estrutura dos arquivos incluidos neste pacote. Os testes individuais foram organizados a partir das rotinas do projeto; o teste do RC522 preserva o sketch isolado validado. As novas versoes organizadas devem ser conferidas na bancada antes de serem registradas como validadas.

```text
hardware/
├── README.md
├── documentacao/
│   └── imagens/
│       └── wokwi/
│           └── LEIA-ME.md
├── firmware/
│   └── controle_acesso/
│       └── controle_acesso.ino
├── simulacao/
│   └── wokwi/
│       ├── sketch.ino
│       ├── diagram.json
│       └── libraries.txt
└── testes/
    ├── leds/
    │   └── leds.ino
    ├── buzzer/
    │   └── buzzer.ino
    ├── servo/
    │   └── servo.ino
    ├── infravermelho/
    │   └── infravermelho.ino
    ├── oled/
    │   └── oled.ino
    └── rc522/
        └── rc522.ino
```

- **firmware:** versão integrada destinada ao ESP32 físico. Registrar os ajustes e a versão efetivamente validada na montagem.
- **simulacao/wokwi:** versão reproduzível do circuito virtual e do código de teste.
- **testes:** códigos isolados para verificar componentes e auxiliar no diagnóstico.

Os arquivos individuais não devem ser compilados todos juntos. Cada teste corresponde a um sketch independente, com pasta e arquivo principal de mesmo nome.

## Componentes

- ESP32.
- Protoboard e jumpers.
- Leitor RFID RC522 e cartão/tag compatível.
- Display OLED I2C de 128 × 64 pixels.
- Sensor de obstáculos reflexivo infravermelho.
- Microservo para representar o trinco.
- Buzzer para sinalização sonora de liberação e negação.
- LEDs amarelo, verde e vermelho.
- Um resistor em série com cada LED.
- Alimentação adequada aos componentes, com GND comum.

No Wokwi, uma chave deslizante representa a saída digital do sensor infravermelho. O diagrama atual usa resistores de 1 kΩ nos LEDs. Os valores dos componentes físicos devem ser conferidos na montagem.

O módulo GPS GY-NEO6MV2 será testado na próxima sprint; ele não está representado no diagrama atual.

## Pinagem da versão integrada atual

Os números abaixo são GPIOs do ESP32, e não posições físicas no conector.

| Componente | Sinal | GPIO |
| --- | --- | --- |
| Sensor infravermelho / chave virtual | OUT / terminal central 2 | 27 |
| Microservo | Sinal | 25 |
| Buzzer | Acionamento | 26 |
| LED amarelo | Saída através de resistor | 32 |
| LED verde | Saída através de resistor | 33 |
| LED vermelho | Saída através de resistor | 14 |
| OLED | SDA | 21 |
| OLED | SCL | 13 |
| RC522 | SDA / SS / CS | 5 |
| RC522 | RST | 22 |
| RC522 | SCK | 18 |
| RC522 | MISO | 19 |
| RC522 | MOSI | 23 |

O pino chamado **SDA** no RC522 é usado como **SS/CS** na comunicação SPI deste projeto.

O teste isolado do RC522 funcionou com CS no GPIO 5 e RST no GPIO 22. Na versão integrada atual, o SCL do OLED foi transferido para o GPIO 13 para evitar conflito com o RST do leitor. Essa combinação foi testada no Wokwi; a integração física com essa pinagem ainda deve ser confirmada.

### Alimentação

- RC522: 3,3 V.
- Sensor infravermelho: utilizado em 3,3 V nos testes físicos.
- OLED: barramento de 3,3 V no diagrama atual.
- Microservo: alimentação externa regulada de 5 V na montagem física, com GND comum ao ESP32.
- LEDs: acionados pelos GPIOs através de resistores; não são ligados diretamente ao trilho positivo.
- Buzzer: componente de sinalização sonora, utilizado com referência GND comum e acionamento pelo circuito do ESP32. Emite um bipe na liberação e três na negação. Seu funcionamento foi validado nos testes individuais e na integração com os demais componentes. O modelo e as especificações elétricas não estão registrados neste levantamento.

No Wokwi, o servo está conectado ao VIN da placa virtual. Essa representação não substitui o dimensionamento da alimentação física.

## Funcionamento do teste integrado

1. O sistema inicia com o trinco fechado.
2. A presença deve permanecer ativa continuamente por três segundos.
3. Durante a confirmação, o LED amarelo pisca.
4. Ao concluir a confirmação, o amarelo fica aceso e o OLED mostra um QR fixo com o texto `ACESSO-TESTE`.
5. O sistema aceita a leitura de uma tag ou um comando de teste pelo monitor serial.
6. A liberação acende o verde, emite um bipe e movimenta o servo para 90 graus.
7. Após três segundos, o servo retorna a zero grau.
8. A negação acende o vermelho, emite três bipes e mantém o trinco fechado.
9. Para outra tentativa, é necessário retirar a presença e aproximar novamente.

Se a presença for interrompida antes dos três segundos, a confirmação é cancelada. Uma tag apresentada antes do estado de espera por decisão tem o UID exibido, mas não libera o acesso; deve ser retirada e apresentada novamente após a confirmação.

### Autorização local de demonstração

Na simulação atual, o UID autorizado é:

```text
01:02:03:04
```

Outros UIDs são negados. Essa comparação local serve para testar o fluxo e será substituída pela decisão do backend.

O QR fixo não realiza autenticação e sua leitura pelo celular não envia uma autorização ao ESP32 nesta versão. A autorização por QR continua representada pelos comandos do monitor serial.

### Comandos do monitor serial

Velocidade: **115200 baud**.

| Comando | Ação |
| --- | --- |
| L | Simula liberação, após confirmação de presença |
| N | Simula negação, após confirmação de presença |
| G | Exibe coordenadas fixas de GPS simulado |

As coordenadas demonstrativas são latitude `48.117300` e longitude `11.516667`. Elas não representam a posição real do dispositivo. O comando G não testa o GY-NEO6MV2, recepção de satélites ou comunicação UART.

## Bibliotecas e ambiente

Para os testes físicos, utilizar a Arduino IDE com o pacote **esp32 by Espressif Systems** e a placa **ESP32 Dev Module**, conforme o ambiente usado nos testes.

Bibliotecas externas:

- Adafruit GFX Library.
- Adafruit SSD1306.
- ESP32Servo.
- MFRC522.

Instalar também as dependências solicitadas pelo gerenciador, como Adafruit BusIO. As bibliotecas Wire e SPI acompanham o pacote da placa.

A versão atual não utiliza TinyGPSPlus, pois o GPS simulado apenas imprime coordenadas fixas.

Conteúdo de `simulacao/wokwi/libraries.txt`:

```text
Adafruit GFX Library
Adafruit SSD1306
ESP32Servo
MFRC522
```

## Executar no Wokwi

1. Abra um projeto ESP32 no Wokwi.
2. Copie os conteúdos de `sketch.ino`, `diagram.json` e `libraries.txt` para as respectivas abas.
3. Inicie a simulação.
4. Acione a chave de presença para conectar o GPIO 27 ao GND.
5. Aguarde três segundos e a exibição do QR.
6. Apresente a tag virtual autorizada.
7. Confira a mensagem de liberação, o LED verde, o bipe e o retorno do servo após três segundos.
8. Retire a presença e repita o processo com outro UID para testar a negação.
9. Envie G no monitor serial para exibir os dados fictícios de localização.

O terminal 1 da chave permanece sem conexão. O terminal 2 vai ao GPIO 27 e o terminal 3 ao GND. A entrada usa `INPUT_PULLUP`, portanto presença ativa corresponde a nível LOW.

## Firmware físico deste pacote

O arquivo `firmware/controle_acesso/controle_acesso.ino` é derivado da simulação atual e foi preparado para a bancada. O RC522 está desativado por padrão (`ATIVAR_RFID 0`) enquanto aguarda revisão de solda; a autorização é testada pelos comandos L/N. Não contém GPS fictício. A revisão integrada com OLED SCL13 deve ser validada fisicamente. Após revisão do leitor, `ATIVAR_RFID 1` habilita o teste local por UID.

O projeto Wokwi mantém RFID ativo e o comando G para coordenadas fixas.

## Executar na montagem física

1. Com a alimentação desligada, confira a pinagem e as tensões da montagem.
2. Abra o sketch do componente ou a versão de firmware destinada à montagem física.
3. Selecione a placa ESP32 Dev Module e a porta correspondente.
4. Confira as bibliotecas utilizadas e envie o código pela opção de upload.
5. Abra o monitor serial em 115200 baud.
6. Registre o resultado e a pinagem efetivamente utilizada.

A versão do Wokwi contém autorização local e localização fictícia. Esses comportamentos devem permanecer identificados ao reutilizar o código no ESP32 físico.

## Próxima sprint

- Revisar o RC522 e concluir a validação física integrada.
- Testar o módulo GPS GY-NEO6MV2.
- Integrar o ESP32 ao broker MQTT e ao backend.
- Substituir a decisão local de teste pela resposta do backend.
- Definir com o grupo o fluxo final de autenticação por QR e por tag.
- Ajustar o QR Code para facilitar a leitura direta pelo celular.
- Preparar o suporte físico/maquete para os componentes.

Na arquitetura prevista, o ESP32 lê a credencial e envia a solicitação pelo broker MQTT. O backend verifica a autorização e retorna a decisão; o ESP32 executa o acionamento e a sinalização.


## Foto do protótipo

Adicione a captura de tela do Wokwi em `documentacao/imagens/wokwi/prototipo-wokwi.png`. A pasta já está reservada no pacote.

## Limitações desta entrega

O pacote não inclui integração MQTT/backend nem leitura de GPS físico. A autorização por UID é apenas demonstrativa. Os códigos foram organizados e revisados, mas esta entrega não foi recompilada nem reexecutada automaticamente; o teste informado da simulação foi realizado pela autora no Wokwi antes do empacotamento.
