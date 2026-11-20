// LEDs: GPIO32 amarelo, GPIO33 verde, GPIO14 vermelho.
// Cada LED com resistor em serie e catodo no GND.
const int leds[]={32,33,14};
void setup(){ Serial.begin(115200); for(int p:leds){pinMode(p,OUTPUT);digitalWrite(p,LOW);} }
void loop(){
 for(int p:leds){Serial.print("LED GPIO ");Serial.println(p);digitalWrite(p,HIGH);delay(1000);digitalWrite(p,LOW);}
 delay(500);
}

