
#include <Wire.h>
#include <SPI.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "mqtt_porta.h"

// ======================================
// PINOS
// ======================================

const int PRESENCA = 27;
const int BUZZER = 4;
const int AMARELO = 16;
const int VERDE = 17;
const int VERMELHO = 14;

const int MOTOR[] = {25, 26, 32, 33};

// RC522
#define SS_PIN   5
#define RST_PIN  22
#define SCK_PIN  18
#define MISO_PIN 19
#define MOSI_PIN 23

// Frequencia que funcionou nos testes
#define SPI_SPEED 1000000

SPISettings spiConfig(
  SPI_SPEED,
  MSBFIRST,
  SPI_MODE0
);

// ======================================
// REGISTRADORES RC522
// ======================================

#define CommandReg       0x01
#define ComIrqReg        0x04
#define DivIrqReg        0x05
#define ErrorReg         0x06
#define FIFODataReg      0x09
#define FIFOLevelReg     0x0A
#define ControlReg       0x0C
#define BitFramingReg    0x0D
#define ModeReg          0x11
#define TxControlReg     0x14
#define TxASKReg         0x15
#define CRCResultRegH    0x21
#define CRCResultRegL    0x22
#define TModeReg         0x2A
#define TPrescalerReg    0x2B
#define TReloadRegH      0x2C
#define TReloadRegL      0x2D
#define VersionReg       0x37

#define PCD_Idle         0x00
#define PCD_CalcCRC      0x03
#define PCD_Transceive   0x0C
#define PCD_SoftReset    0x0F

// ======================================
// CONFIGURACOES
// ======================================

const int PASSOS_PORTA = 1024;

const unsigned long INTERVALO_PASSO = 5;
const unsigned long TEMPO_PRESENCA = 3000;

// Evita multiplas aberturas com a mesma tag
const unsigned long TEMPO_REARME_NFC = 1500;

// Intervalo entre tentativas NFC
const unsigned long INTERVALO_NFC = 100;

// ======================================
// DISPLAY
// ======================================

Adafruit_SSD1306 display(
  128,
  64,
  &Wire,
  -1
);

// ======================================
// MOTOR
// ======================================

const byte sequencia[8][4] = {
  {1, 0, 0, 0},
  {1, 1, 0, 0},
  {0, 1, 0, 0},
  {0, 1, 1, 0},
  {0, 0, 1, 0},
  {0, 0, 1, 1},
  {0, 0, 0, 1},
  {1, 0, 0, 1}
};

// ======================================
// ESTADOS
// ======================================

enum Estado {
  ESPERANDO,
  CONFIRMANDO,
  QR_VISIVEL,
  ABRINDO,
  ABERTO,
  FECHANDO,
  NEGADO,
  ENCERRADO
};

Estado estado = ESPERANDO;

unsigned long inicioEstado = 0;

bool presente = false;
bool ultimaLeitura = false;

unsigned long inicioLeitura = 0;

int fase = 0;
int passosRestantes = 0;
int sentidoMotor = 1;

unsigned long ultimoPasso = 0;
unsigned long tempoAberto = 0;

// ======================================
// CONTROLE NFC
// ======================================

bool nfcArmado = true;

unsigned long ultimaTentativaNFC = 0;
unsigned long inicioAusenciaNFC = 0;

// ======================================
// DISPLAY
// ======================================

void mostrarMensagem(const char* mensagem) {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);

  display.setCursor(0, 28);
  display.println(mensagem);

  display.display();
}

void mostrarQR(const uint8_t* bitmap) {
  constexpr int escala = 2;
  constexpr int margem = 4;
  constexpr int lado = (QR_MODULOS + 2 * margem) * escala;
  const int x = (display.width() - lado) / 2;
  const int y = (display.height() - lado) / 2;
  display.clearDisplay();
  display.fillRect(x, y, lado, lado, SSD1306_WHITE);
  for (int linha = 0; linha < QR_MODULOS; ++linha) {
    for (int coluna = 0; coluna < QR_MODULOS; ++coluna) {
      const int bit = linha * QR_MODULOS + coluna;
      if (bitmap[bit / 8] & (0x80 >> (bit % 8))) {
        display.fillRect(x + (coluna + margem) * escala,
                         y + (linha + margem) * escala, escala, escala, SSD1306_BLACK);
      }
    }
  }

  display.display();
}

// ======================================
// LEDS E ESTADOS
// ======================================

void atualizarLeds() {
  bool piscar =
    estado == CONFIRMANDO &&
    ((millis() - inicioEstado) / 250) % 2 == 0;

  bool liberado =
    estado == ABRINDO ||
    estado == ABERTO;

  digitalWrite(
    AMARELO,
    piscar || estado == QR_VISIVEL
  );

  digitalWrite(VERDE, liberado);
  digitalWrite(VERMELHO, estado == NEGADO);
}

void mudarEstado(Estado novo) {
  estado = novo;
  inicioEstado = millis();

  atualizarLeds();
}

// ======================================
// BUZZER
// ======================================

void tocarBipes(int quantidade) {
  for (int bipe = 0; bipe < quantidade; bipe++) {
    for (int ciclo = 0; ciclo < 200; ciclo++) {
      digitalWrite(BUZZER, HIGH);
      delayMicroseconds(250);

      digitalWrite(BUZZER, LOW);
      delayMicroseconds(250);
    }

    if (bipe < quantidade - 1) {
      delay(150);
    }
  }
}

// ======================================
// MOTOR
// ======================================

void desligarBobinas() {
  for (int i = 0; i < 4; i++) {
    digitalWrite(MOTOR[i], LOW);
  }
}

void iniciarMovimento(int sentido) {
  sentidoMotor = sentido;
  passosRestantes = PASSOS_PORTA;

  ultimoPasso = millis();
}

void atualizarMotor() {
  if (passosRestantes <= 0) return;

  if (millis() - ultimoPasso < INTERVALO_PASSO) {
    return;
  }

  ultimoPasso = millis();

  fase = (fase + sentidoMotor + 8) % 8;

  for (int i = 0; i < 4; i++) {
    digitalWrite(
      MOTOR[i],
      sequencia[fase][i]
    );
  }

  passosRestantes--;

  if (passosRestantes == 0) {
    desligarBobinas();
  }
}

// ======================================
// SENSOR DE PRESENCA
// ======================================

void atualizarSensor() {
  bool leitura =
    digitalRead(PRESENCA) == LOW;

  if (leitura != ultimaLeitura) {
    ultimaLeitura = leitura;
    inicioLeitura = millis();
  }

  if (millis() - inicioLeitura >= 100) {
    presente = leitura;
  }
}

// ======================================
// GPS SIMULADO
// ======================================

void mostrarGPS() {
  Serial.println(
    "\n--- LOCALIZACAO SIMULADA ---"
  );

  Serial.println("Latitude: 48.117300");
  Serial.println("Longitude: 11.516667");

  Serial.println(
    "Valores programados, nao localizacao real."
  );

  Serial.println(
    "GPS fisico nao validado."
  );
}

// ======================================
// SPI RC522 - 1 MHz
// ======================================

void escrever(byte reg, byte valor) {
  SPI.beginTransaction(spiConfig);

  digitalWrite(SS_PIN, LOW);

  SPI.transfer((reg << 1) & 0x7E);
  SPI.transfer(valor);

  digitalWrite(SS_PIN, HIGH);

  SPI.endTransaction();
}

byte ler(byte reg) {
  SPI.beginTransaction(spiConfig);

  digitalWrite(SS_PIN, LOW);

  SPI.transfer(
    0x80 | ((reg << 1) & 0x7E)
  );

  byte valor = SPI.transfer(0x00);

  digitalWrite(SS_PIN, HIGH);

  SPI.endTransaction();

  return valor;
}

void setBits(byte reg, byte mask) {
  escrever(reg, ler(reg) | mask);
}

void clearBits(byte reg, byte mask) {
  escrever(reg, ler(reg) & ~mask);
}

// ======================================
// INICIAR RC522
// ======================================

void iniciarRC522() {
  escrever(CommandReg, PCD_SoftReset);
  delay(100);

  escrever(TModeReg, 0x80);
  escrever(TPrescalerReg, 0xA9);

  escrever(TReloadRegH, 0x03);
  escrever(TReloadRegL, 0xE8);

  escrever(TxASKReg, 0x40);
  escrever(ModeReg, 0x3D);

  setBits(TxControlReg, 0x03);

  Serial.println("\n--- RC522 ---");

  Serial.print("VersionReg: 0x");
  Serial.println(ler(VersionReg), HEX);

  Serial.print("TxControlReg: 0x");
  Serial.println(ler(TxControlReg), HEX);

  Serial.println("SPI: 1 MHz");

  if ((ler(TxControlReg) & 0x03) == 0x03) {
    Serial.println(
      "Transmissores habilitados."
    );
  } else {
    Serial.println(
      "ERRO: transmissores desabilitados."
    );
  }
}

// ======================================
// CRC_A
// ======================================

bool calcularCRC(
  const byte *dados,
  byte tamanho,
  byte *crc
) {
  escrever(CommandReg, PCD_Idle);
  escrever(DivIrqReg, 0x04);
  escrever(FIFOLevelReg, 0x80);

  for (byte i = 0; i < tamanho; i++) {
    escrever(FIFODataReg, dados[i]);
  }

  escrever(CommandReg, PCD_CalcCRC);

  unsigned long inicio = millis();

  while (millis() - inicio < 50) {
    if (ler(DivIrqReg) & 0x04) {
      escrever(CommandReg, PCD_Idle);

      crc[0] = ler(CRCResultRegL);
      crc[1] = ler(CRCResultRegH);

      return true;
    }
  }

  escrever(CommandReg, PCD_Idle);
  return false;
}

// ======================================
// COMUNICACAO RFID
// ======================================

bool comunicar(
  const byte *dados,
  byte tamanho,
  byte *resposta,
  byte *tamanhoResposta,
  byte txLastBits = 0,
  byte *rxLastBits = nullptr
) {
  escrever(CommandReg, PCD_Idle);
  escrever(ComIrqReg, 0x7F);
  escrever(FIFOLevelReg, 0x80);

  for (byte i = 0; i < tamanho; i++) {
    escrever(FIFODataReg, dados[i]);
  }

  escrever(
    BitFramingReg,
    txLastBits & 0x07
  );

  escrever(CommandReg, PCD_Transceive);
  setBits(BitFramingReg, 0x80);

  unsigned long inicio = millis();
  byte irq = 0;

  while (millis() - inicio < 50) {
    irq = ler(ComIrqReg);

    if (irq & 0x30) break;
    if (irq & 0x01) break;
  }

  clearBits(BitFramingReg, 0x80);

  if (!(irq & 0x30)) {
    escrever(CommandReg, PCD_Idle);
    return false;
  }

  if (ler(ErrorReg) & 0x1B) {
    escrever(CommandReg, PCD_Idle);
    return false;
  }

  byte quantidade = ler(FIFOLevelReg);

  if (
    quantidade == 0 ||
    quantidade > *tamanhoResposta
  ) {
    escrever(CommandReg, PCD_Idle);
    return false;
  }

  if (rxLastBits != nullptr) {
    *rxLastBits = ler(ControlReg) & 0x07;
  }

  for (byte i = 0; i < quantidade; i++) {
    resposta[i] = ler(FIFODataReg);
  }

  *tamanhoResposta = quantidade;

  escrever(CommandReg, PCD_Idle);

  return true;
}

// ======================================
// DETECTAR TAG ISO14443-A
// ======================================

bool detectarTag() {
  byte comando[] = {0x52}; // WUPA também detecta a tag após HLTA.

  byte resposta[4];
  byte tamanho = sizeof(resposta);
  byte bitsFinais = 0;

  if (!comunicar(
    comando,
    1,
    resposta,
    &tamanho,
    7,
    &bitsFinais
  )) {
    return false;
  }

  return tamanho == 2 && bitsFinais == 0;
}

// ======================================
// ANTICOLISAO
// ======================================

bool anticollision(
  byte nivel,
  byte *resultado
) {
  byte comando[] = {nivel, 0x20};

  byte resposta[10];
  byte tamanho = sizeof(resposta);
  byte bitsFinais = 0;

  if (!comunicar(
    comando,
    2,
    resposta,
    &tamanho,
    0,
    &bitsFinais
  )) {
    return false;
  }

  if (tamanho != 5 || bitsFinais != 0) {
    return false;
  }

  byte bcc =
    resposta[0] ^
    resposta[1] ^
    resposta[2] ^
    resposta[3];

  if (bcc != resposta[4]) {
    return false;
  }

  memcpy(resultado, resposta, 5);

  return true;
}

// ======================================
// SELECAO CL1 / CL2 / CL3
// ======================================

bool selecionar(
  byte nivel,
  const byte *uidNivel,
  bool *continua
) {
  byte comando[9];

  comando[0] = nivel;
  comando[1] = 0x70;

  memcpy(&comando[2], uidNivel, 5);

  if (!calcularCRC(
    comando,
    7,
    &comando[7]
  )) {
    return false;
  }

  byte resposta[5];
  byte tamanho = sizeof(resposta);
  byte bitsFinais = 0;

  if (!comunicar(
    comando,
    9,
    resposta,
    &tamanho,
    0,
    &bitsFinais
  )) {
    return false;
  }

  if (tamanho != 3 || bitsFinais != 0) {
    return false;
  }

  byte crc[2];

  if (!calcularCRC(resposta, 1, crc)) {
    return false;
  }

  if (
    resposta[1] != crc[0] ||
    resposta[2] != crc[1]
  ) {
    return false;
  }

  *continua =
    (resposta[0] & 0x04) != 0;

  return true;
}

// ======================================
// LER UID COMPLETO
// 4, 7 OU 10 BYTES
// ======================================

bool lerUID(
  byte *uid,
  byte *tamanhoUID
) {
  *tamanhoUID = 0;

  if (!detectarTag()) {
    return false;
  }

  const byte niveis[3] = {
    0x93,  // CL1
    0x95,  // CL2
    0x97   // CL3
  };

  bool continua = false;

  for (byte nivel = 0; nivel < 3; nivel++) {
    byte resultado[5];

    if (!anticollision(
      niveis[nivel],
      resultado
    )) {
      return false;
    }

    if (!selecionar(
      niveis[nivel],
      resultado,
      &continua
    )) {
      return false;
    }

    // 0x88 indica UID com mais niveis
    bool cascadeTag = resultado[0] == 0x88;

    if (continua) {
      if (!cascadeTag || nivel == 2) {
        return false;
      }

      // Ignora o marcador 0x88
      // Copia os 3 bytes reais
      for (byte i = 1; i < 4; i++) {
        uid[*tamanhoUID] = resultado[i];
        (*tamanhoUID)++;
      }

    } else {
      if (cascadeTag) {
        return false;
      }

      // Ultimo nivel: 4 bytes
      for (byte i = 0; i < 4; i++) {
        uid[*tamanhoUID] = resultado[i];
        (*tamanhoUID)++;
      }

      return true;
    }
  }

  return false;
}

// ======================================
// IMPRIMIR UID
// ======================================

void imprimirUID(
  const byte *uid,
  byte tamanho
) {
  Serial.println();
  Serial.println("=== TAG DETECTADA ===");

  Serial.print("UID: ");

  for (byte i = 0; i < tamanho; i++) {
    if (i > 0) Serial.print(":");

    if (uid[i] < 0x10) {
      Serial.print("0");
    }

    Serial.print(uid[i], HEX);
  }

  Serial.println();

  Serial.print("Tamanho: ");
  Serial.print(tamanho);
  Serial.println(" bytes");

  Serial.println("====================");
}

// ======================================
// LIBERAR PORTA
// ======================================

void iniciarAbertura(unsigned long duracao) {
  tempoAberto = duracao;
  mudarEstado(ABRINDO);

  mostrarMensagem("Acesso liberado");

  Serial.println();
  Serial.println("Acesso liberado via MQTT.");

  tocarBipes(1);
  iniciarMovimento(1);
}

// ======================================
// CONTROLE NFC
// ======================================

void atualizarNFC() {
  // Nunca executar comunicacao NFC
  // durante movimento do motor.
  if (
    estado == ABRINDO ||
    estado == FECHANDO
  ) {
    return;
  }

  if (
    millis() - ultimaTentativaNFC <
    INTERVALO_NFC
  ) {
    return;
  }

  ultimaTentativaNFC = millis();

  byte uid[10];
  byte tamanhoUID = 0;

  bool detectada = lerUID(
    uid,
    &tamanhoUID
  );

  if (detectada) {
    // Após SELECT, coloque a tag em HALT para detectá-la na próxima WUPA.
    byte halt[] = {0x50, 0x00, 0, 0};
    if (calcularCRC(halt, 2, halt + 2)) {
      byte resposta[1];
      byte tamanho = sizeof(resposta);
      comunicar(halt, sizeof(halt), resposta, &tamanho);
    }
    inicioAusenciaNFC = 0;

    if (!nfcArmado) {
      return;
    }

    // Bloqueia repeticoes da mesma
    // aproximacao ate remover a tag
    nfcArmado = false;

    imprimirUID(uid, tamanhoUID);

    if (solicitarAcessoNfc(uid, tamanhoUID)) {
      mostrarMensagem("Validando tag");
    } else {
      Serial.println("[NFC] Pedido indisponivel.");
    }

    return;
  }

  // Apos um ciclo, exige ausencia
  // da tag antes de rearmar.
  if (!nfcArmado) {
    if (inicioAusenciaNFC == 0) {
      inicioAusenciaNFC = millis();
    }

    if (
      millis() - inicioAusenciaNFC >=
      TEMPO_REARME_NFC
    ) {
      nfcArmado = true;
      inicioAusenciaNFC = 0;

      Serial.println(
        "[NFC] Leitor rearmado."
      );
    }
  }
}

// ======================================
// SETUP
// ======================================

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("[BOOT] Setup iniciado.");

  pinMode(PRESENCA, INPUT_PULLUP);

  pinMode(BUZZER, OUTPUT);
  pinMode(AMARELO, OUTPUT);
  pinMode(VERDE, OUTPUT);
  pinMode(VERMELHO, OUTPUT);

  digitalWrite(BUZZER, LOW);

  for (int i = 0; i < 4; i++) {
    pinMode(MOTOR[i], OUTPUT);
  }

  desligarBobinas();
  atualizarLeds();

  // OLED
  Serial.println("[BOOT] Inicializando OLED.");
  Wire.begin(21, 13);

  if (!display.begin(
    SSD1306_SWITCHCAPVCC,
    0x3C,
    true,
    false
  )) {
    Serial.println(
      "Falha ao iniciar o OLED."
    );

    while (true) {
      delay(1000);
    }
  }

  // RC522
  Serial.println("[BOOT] Inicializando RC522.");
  pinMode(SS_PIN, OUTPUT);
  digitalWrite(SS_PIN, HIGH);

  pinMode(RST_PIN, OUTPUT);
  digitalWrite(RST_PIN, HIGH);

  SPI.begin(
    SCK_PIN,
    MISO_PIN,
    MOSI_PIN,
    SS_PIN
  );

  iniciarRC522();

  ultimaLeitura =
    digitalRead(PRESENCA) == LOW;

  inicioLeitura = millis();

  mudarEstado(ESPERANDO);
  mostrarMensagem("Aproxime-se");

  Serial.println();
  Serial.println(
    "=== SISTEMA DE ACESSO ==="
  );

  Serial.println(
    "NFC habilitado: UID 4/7/10 bytes"
  );

  Serial.println(
    "SPI configurado em 1 MHz"
  );

  Serial.println(
    "Motor inicia na posicao fechada."
  );

  Serial.println(
    "Sem sensor de fim de curso."
  );

  mostrarGPS();
  // Teste de bancada por USB, antes da implementacao da ponte serial.
  Serial.println("[BOOT] Teste USB: Wi-Fi e MQTT desativados.");
  Serial.println("[BOOT] Setup concluido.");
}

// ======================================
// LOOP PRINCIPAL
// ======================================

void loop() {
  atualizarSensor();
  atualizarMotor();

  switch (estado) {

    case ESPERANDO:
      if (presente) {
        mudarEstado(CONFIRMANDO);

        mostrarMensagem(
          "Aguarde 3 segundos"
        );

        Serial.println(
          "Confirmando presenca..."
        );
      }
      break;

    case CONFIRMANDO:
      if (!presente) {
        mudarEstado(ESPERANDO);

        mostrarMensagem("Aproxime-se");

        Serial.println(
          "Contagem cancelada."
        );

      } else if (
        millis() - inicioEstado >=
        TEMPO_PRESENCA
      ) {
        mudarEstado(QR_VISIVEL);
        mostrarMensagem("Aguardando QR");
      }
      break;

    case QR_VISIVEL:
      if (!presente) {
        mudarEstado(ESPERANDO);

        mostrarMensagem("Aproxime-se");

        Serial.println(
          "Tentativa cancelada por afastamento."
        );
      }
      break;

    case ABRINDO:
      if (passosRestantes == 0) {
        confirmarAberturaMqtt();
        mudarEstado(ABERTO);

        mostrarMensagem("Porta aberta");

        Serial.println(
          "Abertura comandada concluida."
        );
      }
      break;

    case ABERTO:
      if (
        millis() - inicioEstado >=
        tempoAberto
      ) {
        mudarEstado(FECHANDO);

        mostrarMensagem("Fechando...");

        iniciarMovimento(-1);
      }
      break;

    case FECHANDO:
      if (passosRestantes == 0) {
        confirmarFechamentoMqtt();
        mudarEstado(ENCERRADO);

        mostrarMensagem(
          "Ciclo encerrado"
        );

        Serial.println(
          "Fechamento comandado concluido."
        );

        Serial.println(
          "Retire a presenca para nova tentativa."
        );
      }
      break;

    case NEGADO:
      if (
        millis() - inicioEstado >= 2000
      ) {
        mudarEstado(ENCERRADO);

        mostrarMensagem(
          "Retire o objeto"
        );
      }
      break;

    case ENCERRADO:
      if (!presente) {
        mudarEstado(ESPERANDO);

        mostrarMensagem("Aproxime-se");

        Serial.println(
          "Pronto para nova tentativa."
        );
      }
      break;
  }

  bool nfcNegado;
  const unsigned long duracao = atualizarMqttPorta(presente, nfcNegado);
  if (duracao != 0) {
    iniciarAbertura(duracao);
  } else if (nfcNegado) {
    mudarEstado(NEGADO);
    mostrarMensagem("Acesso negado");
    tocarBipes(3);
  }

  uint8_t bitmapQr[QR_BYTES];
  const AtualizacaoQr qr = atualizarQrMqtt(estado == QR_VISIVEL && presente, bitmapQr);
  if (qr == AtualizacaoQr::Exibir) mostrarQR(bitmapQr);
  if (qr == AtualizacaoQr::Limpar) mostrarMensagem("Aguardando QR");

  // A leitura NFC acontece apenas
  // quando nao ha movimento do motor.
  atualizarNFC();

  atualizarLeds();

  delay(1);
}
