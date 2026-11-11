#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
// OLED: VCC 3,3 V, GND, SDA21, SCL13. Endereco 0x3C.
Adafruit_SSD1306 display(128,64,&Wire,-1);
void setup(){
 Serial.begin(115200);Wire.begin(21,13);
 if(!display.begin(SSD1306_SWITCHCAPVCC,0x3C,true,false)){
  Serial.println("Falha ao iniciar OLED.");while(true)delay(100);
 }
 display.clearDisplay();display.setTextColor(SSD1306_WHITE);
 display.setTextSize(1);display.setCursor(0,10);display.println("OLED OK");
 display.println("Controle de acesso");display.display();Serial.println("OLED OK");
}
void loop(){delay(100);}

