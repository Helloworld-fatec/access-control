#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <ESP32Servo.h>
#include <SPI.h>
#include <MFRC522.h>

const int PRESENCA=27, SERVO=25, BUZZER=26;
const int AMARELO=32, VERDE=33, VERMELHO=14;
const int OLED_SDA=21, OLED_SCL=13;
const int RFID_CS=5, RFID_RST=22;
const int RFID_SCK=18, RFID_MISO=19, RFID_MOSI=23;
Adafruit_SSD1306 display(128,64,&Wire,-1);
Servo trinco;
MFRC522 leitor(RFID_CS,RFID_RST);
const int TRAVADO=0, DESTRAVADO=90;
const unsigned long TEMPO_PRESENCA=3000, TEMPO_TRINCO=3000;
const byte TAG_AUTORIZADA[]={0x01,0x02,0x03,0x04};
enum Estado { ESPERANDO, CONFIRMANDO, QR_VISIVEL, LIBERADO, NEGADO, ENCERRADO };
Estado estado=ESPERANDO;
unsigned long inicioEstado=0;
const uint32_t qr[]={
0b111111101000101111111,
0b100000101101001000001,
0b101110101111101011101,
0b101110101010101011101,
0b101110100111101011101,
0b100000101010101000001,
0b111111101010101111111,
0b000000000000000000000,
0b110011100000100101111,
0b101011000110101100111,
0b110000111010100010110,
0b000101000001110010010,
0b011101100011011110111,
0b000000001010101011111,
0b111111100111010110010,
0b100000101110010000000,
0b101110101111101111100,
0b101110100100111000111,
0b101110100010011010100,
0b100000101011010000000,
0b111111101011101001101
};
void mostrarMensagem(const char* mensagem){
 display.clearDisplay(); display.setTextSize(1);
 display.setTextColor(SSD1306_WHITE); display.setCursor(4,28);
 display.print(mensagem); display.display();
}
void mostrarQR(){
 display.clearDisplay(); display.fillRect(35,3,58,58,SSD1306_WHITE);
 for(int linha=0;linha<21;linha++)
  for(int coluna=0;coluna<21;coluna++)
   if((qr[linha]>>(20-coluna))&1u)
    display.fillRect(43+coluna*2,11+linha*2,2,2,SSD1306_BLACK);
 display.display();
}
void atualizarLeds(){
 bool pisca=estado==CONFIRMANDO && ((millis()-inicioEstado)/250)%2==0;
 digitalWrite(AMARELO,estado==QR_VISIVEL || pisca);
 digitalWrite(VERDE,estado==LIBERADO); digitalWrite(VERMELHO,estado==NEGADO);
}
void mudarEstado(Estado novo){
 estado=novo; inicioEstado=millis(); atualizarLeds();
}
void tocarBipes(int quantidade){
 // Sinalizacao sonora testada: um bipe libera, tres negam.
 for(int bipe=0;bipe<quantidade;bipe++){
  for(int ciclo=0;ciclo<200;ciclo++){
   digitalWrite(BUZZER,HIGH); delayMicroseconds(250);
   digitalWrite(BUZZER,LOW); delayMicroseconds(250);
  }
  if(bipe+1<quantidade) delay(90);
 }
}
void testarGPS(){
 Serial.println("\n--- GPS SIMULADO ---");
 Serial.println("Latitude: 48.117300");
 Serial.println("Longitude: 11.516667");
 Serial.println("Coordenadas fixas de teste.");
 Serial.println("Nao representam a localizacao real.");
 Serial.println("--------------------");
}
bool podeReceberDecisao(){
 return estado==QR_VISIVEL && digitalRead(PRESENCA)==LOW;
}
void liberarAcesso(){
 Serial.println("Decisao de teste: ACESSO LIBERADO.");
 trinco.write(DESTRAVADO); mudarEstado(LIBERADO);
 mostrarMensagem("Acesso liberado"); tocarBipes(1);
}
void negarAcesso(){
 Serial.println("Decisao de teste: ACESSO NEGADO.");
 trinco.write(TRAVADO); mudarEstado(NEGADO);
 mostrarMensagem("Acesso negado"); tocarBipes(3);
}
bool tagAutorizada(){
 if(leitor.uid.size!=sizeof(TAG_AUTORIZADA)) return false;
 for(byte i=0;i<leitor.uid.size;i++)
  if(leitor.uid.uidByte[i]!=TAG_AUTORIZADA[i]) return false;
 return true;
}
void lerTag(){
 if(!leitor.PICC_IsNewCardPresent() || !leitor.PICC_ReadCardSerial()) return;
 Serial.print("UID da tag: ");
 for(byte i=0;i<leitor.uid.size;i++){
  if(i>0) Serial.print(':');
  if(leitor.uid.uidByte[i]<0x10) Serial.print('0');
  Serial.print(leitor.uid.uidByte[i],HEX);
 }
 Serial.println();
 bool autorizada=tagAutorizada();
 leitor.PICC_HaltA(); leitor.PCD_StopCrypto1();
 if(!podeReceberDecisao()){
  Serial.println("Tag lida, mas aguarde a confirmacao de presenca e o QR.");
  Serial.println("Depois, retire e apresente a tag novamente.");
  return;
 }
 Serial.println("Verificando UID na lista local de teste...");
 if(autorizada) liberarAcesso(); else negarAcesso();
}
void setup(){
 Serial.begin(115200); pinMode(PRESENCA,INPUT_PULLUP);
 pinMode(BUZZER,OUTPUT); pinMode(AMARELO,OUTPUT);
 pinMode(VERDE,OUTPUT); pinMode(VERMELHO,OUTPUT);
 digitalWrite(BUZZER,LOW); atualizarLeds();
 trinco.setPeriodHertz(50); trinco.attach(SERVO,500,2400); trinco.write(TRAVADO);
 Wire.begin(OLED_SDA,OLED_SCL);
 if(!display.begin(SSD1306_SWITCHCAPVCC,0x3C,true,false)){
  Serial.println("Falha ao iniciar o OLED."); while(true) delay(100);
 }
 SPI.begin(RFID_SCK,RFID_MISO,RFID_MOSI,RFID_CS); leitor.PCD_Init();
 mostrarMensagem("Aproxime-se");
 Serial.println("\n--- CONTROLE DE ACESSO: TESTE LOCAL ---");
 Serial.println("L = liberar | N = negar | G = GPS simulado");
 Serial.println("Tag autorizada: 01:02:03:04");
 Serial.println("Outros UIDs serao negados.");
 Serial.println("Ative a presenca e aguarde 3 segundos.");
}
void loop(){
 bool presente=digitalRead(PRESENCA)==LOW;
 if(estado==LIBERADO){
  if(millis()-inicioEstado>=TEMPO_TRINCO){
   trinco.write(TRAVADO); mudarEstado(presente?ENCERRADO:ESPERANDO);
   mostrarMensagem(presente?"Trinco fechado":"Aproxime-se");
   Serial.println("Trinco fechado.");
   if(presente) Serial.println("Retire a presenca para iniciar outra tentativa.");
  }
 }else if(!presente){
  if(estado!=ESPERANDO){
   mudarEstado(ESPERANDO); mostrarMensagem("Aproxime-se");
   Serial.println("Sistema pronto para nova aproximacao.");
  }
 }else if(estado==ESPERANDO){
  mudarEstado(CONFIRMANDO); mostrarMensagem("Aguarde 3 segundos");
  Serial.println("Confirmando presenca...");
 }else if(estado==CONFIRMANDO && millis()-inicioEstado>=TEMPO_PRESENCA){
  mudarEstado(QR_VISIVEL); mostrarQR();
  Serial.println("QR visivel. Apresente a tag ou envie L/N.");
 }
 atualizarLeds(); lerTag();
 while(Serial.available()>0){
  char comando=Serial.read();
  if(comando=='G'||comando=='g'){ testarGPS(); continue; }
  if(comando=='L'||comando=='l'||comando=='N'||comando=='n'){
   if(!podeReceberDecisao()){
    Serial.println("Comando ignorado: aguarde o QR."); continue;
   }
   if(comando=='L'||comando=='l') liberarAcesso(); else negarAcesso();
  }
 }
 delay(10);
}

