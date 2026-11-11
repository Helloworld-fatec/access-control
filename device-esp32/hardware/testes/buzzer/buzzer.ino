// Buzzer: sinalizacao sonora no GPIO26; referencia comum GND.
// Teste: um bipe de liberacao e tres de negacao.
// Reproduz a rotina usada no teste integrado.
const int BUZZER=26;
void tocarBipes(int quantidade){
 for(int b=0;b<quantidade;b++){
  for(int c=0;c<200;c++){
   digitalWrite(BUZZER,HIGH);delayMicroseconds(250);
   digitalWrite(BUZZER,LOW);delayMicroseconds(250);
  }
  if(b+1<quantidade)delay(90);
 }
}
void setup(){Serial.begin(115200);pinMode(BUZZER,OUTPUT);digitalWrite(BUZZER,LOW);}
void loop(){
 Serial.println("Liberacao: um bipe");tocarBipes(1);delay(2000);
 Serial.println("Negacao: tres bipes");tocarBipes(3);delay(3000);
}

