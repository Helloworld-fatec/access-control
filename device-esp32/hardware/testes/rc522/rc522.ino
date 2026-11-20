// Teste do RC522 validado na bancada por Bruna em 09/11/2026.
// ESP32 Dev Module: SDA/CS = GPIO5, RST = GPIO22, SPI.begin() padrao.
// GPIO22 tambem era o SCL do OLED: resolver antes de integrar os dois.

#include <SPI.h>
#include <MFRC522.h>

// Define os pinos de controle para o ESP32
#define SS_PIN  5  // Pino SDA
#define RST_PIN 22 // Pino RST

MFRC522 rfid(SS_PIN, RST_PIN);

void setup() {
  Serial.begin(115200);
  SPI.begin();     // Inicializa o barramento SPI padrão (VSPI)
  rfid.PCD_Init(); // Inicializa o leitor RC522
  
  Serial.println("Aproxime o seu cartao ou tag RFID...");
}

void loop() {
  // Verifica se há novos cartões presentes
  if (!rfid.PICC_IsNewCardPresent()) {
    return;
  }
  Serial.println("Cartão presente!");

  // Seleciona um dos cartões
  if (!rfid.PICC_ReadCardSerial()) {
    return;
  }

  Serial.println("Seleção feita.");
  
  // Mostra o UID do cartão no Monitor Serial
  Serial.print("UID da tag: ");
  for (byte i = 0; i < rfid.uid.size; i++) {
    Serial.print(rfid.uid.uidByte[i] < 0x10 ? " 0" : " ");
    Serial.print(rfid.uid.uidByte[i], HEX);
  }
  Serial.println();

  // Para a leitura do cartão atual
  rfid.PICC_HaltA();
}
