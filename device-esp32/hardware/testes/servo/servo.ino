#include <ESP32Servo.h>
// Sinal GPIO25; alimentacao externa regulada 5 V e GND comum.
Servo trinco;
void setup(){
 Serial.begin(115200);trinco.setPeriodHertz(50);
 trinco.attach(25,500,2400);trinco.write(0);
}
void loop(){
 Serial.println("Trinco fechado: 0 graus");trinco.write(0);delay(3000);
 Serial.println("Trinco destravado: 90 graus");trinco.write(90);delay(3000);
}

