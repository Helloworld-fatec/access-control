// Sensor: VCC 3,3 V, GND comum, OUT GPIO27. Deteccao ativa em LOW.
const int PRESENCA=27;
void setup(){Serial.begin(115200);pinMode(PRESENCA,INPUT_PULLUP);}
void loop(){
 Serial.println(digitalRead(PRESENCA)==LOW?"Objeto detectado":"Sem objeto");
 delay(250);
}

