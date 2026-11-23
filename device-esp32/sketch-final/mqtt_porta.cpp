#include "mqtt_porta.h"

#include <Arduino.h>
#include <Preferences.h>
#include <WiFi.h>
#include <atomic>
#include <cJSON.h>
#include <esp_random.h>
#include <esp_sntp.h>
#include <mqtt_client.h>
#include <sys/time.h>

#if __has_include("mqtt_config.h")
#include "mqtt_config.h"
#else
#include "mqtt_config.example.h"
#endif

namespace {
constexpr int64_t PRAZO_ACEITE_MS = 5000;
constexpr int64_t PRAZO_ACK_MS = 10000;
constexpr size_t LIMITE_JSON = 2048;
constexpr int TOTAL_REGISTROS = 16;
constexpr char CHAVE_CICLO[] = "ciclo";

struct Ordem {
  char pedido[37];
  char acesso[37];
  int64_t emitida;
  int64_t vence;
  unsigned long duracao;
};

struct MensagemOrdem {
  Ordem ordem;
  bool nfc;
  bool autorizada;
};

struct PedidoNfc {
  char id[37];
  unsigned long inicio;
  unsigned sessao;
  int64_t vence;
};

PedidoNfc pedidoNfc{};

struct RespostaQr {
  char pedido[37];
  int64_t vence;
  int64_t renovar;
  uint8_t bitmap[QR_BYTES];
};

enum Resultado : uint8_t { INICIADO, UNLOCKED, ERROR, EXPIRED };

struct Registro {
  Ordem ordem;
  char evento[37];
  int64_t aceite;
  int64_t conclusao;
  Resultado resultado;
};

struct Publicacao {
  char topico[96];
  char corpo[512];
};

Preferences memoria;
Registro registros[TOTAL_REGISTROS]{};
int ciclo = -1;
bool recuperacao = false;
QueueHandle_t ordens;
QueueHandle_t respostasQr;
QueueHandle_t publicacoes;
esp_mqtt_client_handle_t mqtt;
std::atomic<bool> relogioSincronizado{false};
std::atomic<bool> conectado{false};
std::atomic<bool> desconectado{false};
std::atomic<unsigned long> falhaEm{0};
std::atomic<unsigned> sessoes{0};
int assinaturas[3]{};
unsigned confirmadas = 0;
char topicoOrdem[96];
char topicoDecisao[96];
char topicoQr[96];
char clientId[48];

int64_t agoraUtc() {
  timeval hora{};
  gettimeofday(&hora, nullptr);
  return static_cast<int64_t>(hora.tv_sec) * 1000 + hora.tv_usec / 1000;
}

void formatarUtc(int64_t ms, char (&saida)[25]) {
  time_t segundos = ms / 1000;
  tm utc{};
  gmtime_r(&segundos, &utc);
  strftime(saida, 20, "%Y-%m-%dT%H:%M:%S", &utc);
  snprintf(saida + 19, 6, ".%03uZ", static_cast<unsigned>(ms % 1000));
}

int64_t lerUtc(const char* texto) {
  if (!texto || strlen(texto) < 20) return 0;
  tm utc{};
  const char* fim = strptime(texto, "%Y-%m-%dT%H:%M:%S", &utc);
  if (fim != texto + 19 || utc.tm_year < 120 || utc.tm_year > 199) return 0;
  unsigned ms = 0;
  if (*fim == '.') {
    ++fim;
    if (*fim < '0' || *fim > '9') return 0;
    for (unsigned casa = 100; *fim >= '0' && *fim <= '9'; casa /= 10, ++fim) {
      ms += (*fim - '0') * casa;
    }
  }
  if (strcmp(fim, "Z") != 0) return 0;
  // configTime(0, 0, ...) fixa o fuso usado por mktime em UTC.
  const int64_t instante = static_cast<int64_t>(mktime(&utc)) * 1000 + ms;
  char normalizado[25];
  formatarUtc(instante, normalizado);
  return strncmp(texto, normalizado, 19) == 0 ? instante : 0;
}

void gerarUuid(char (&saida)[37]) {
  uint8_t bytes[16];
  esp_fill_random(bytes, sizeof(bytes));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  snprintf(saida, sizeof(saida),
           "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
           bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]);
}

bool uuidValido(const char* texto) {
  if (!texto || strlen(texto) != 36) return false;
  for (int i = 0; i < 36; ++i) {
    if (i == 8 || i == 13 || i == 18 || i == 23) {
      if (texto[i] != '-') return false;
    } else if (!isxdigit(static_cast<unsigned char>(texto[i]))) {
      return false;
    }
  }
  return true;
}

const char* textoJson(const cJSON* json, const char* nome) {
  return cJSON_GetStringValue(cJSON_GetObjectItemCaseSensitive(json, nome));
}

bool lerOrdem(const cJSON* json, MensagemOrdem& mensagem) {
  Ordem& ordem = mensagem.ordem;
  const cJSON* versao = cJSON_GetObjectItemCaseSensitive(json, "schemaVersion");
  const cJSON* duracao = cJSON_GetObjectItemCaseSensitive(json, "unlockDurationMs");
  const char* terminal = textoJson(json, "terminalId");
  const char* metodo = textoJson(json, "method");
  const char* pedido = textoJson(json, "requestId");
  const char* acesso = textoJson(json, "accessLogId");
  if (!cJSON_IsNumber(versao) || versao->valuedouble != 1 ||
      !terminal || strcmp(terminal, MQTT_TERMINAL_ID) != 0 ||
      !uuidValido(textoJson(json, "eventId")) || !uuidValido(pedido) ||
      !uuidValido(acesso) || !cJSON_IsNumber(duracao) || duracao->valuedouble < 0 ||
      duracao->valuedouble > TEMPO_ABERTO_MAXIMO || duracao->valuedouble != duracao->valueint) {
    return false;
  }
  ordem.emitida = lerUtc(textoJson(json, mensagem.nfc ? "decidedAt" : "occurredAt"));
  ordem.vence = lerUtc(textoJson(json, "expiresAt"));
  const int64_t prazo = ordem.vence - ordem.emitida;
  if (!ordem.emitida || prazo <= 0 || prazo > PRAZO_ACEITE_MS) return false;
  if (mensagem.nfc) {
    const cJSON* autorizada = cJSON_GetObjectItemCaseSensitive(json, "authorized");
    const cJSON* motivo = cJSON_GetObjectItemCaseSensitive(json, "reason");
    if (!cJSON_IsBool(autorizada) || strcmp(pedido, acesso) == 0) return false;
    mensagem.autorizada = cJSON_IsTrue(autorizada);
    if (mensagem.autorizada ? (duracao->valueint == 0 || !cJSON_IsNull(motivo))
                           : (duracao->valueint != 0 || !cJSON_IsString(motivo) || !motivo->valuestring[0])) {
      return false;
    }
  } else if (strcmp(pedido, acesso) != 0 || prazo != PRAZO_ACEITE_MS || duracao->valueint == 0 ||
             !metodo || (strcmp(metodo, "QR") != 0 && strcmp(metodo, "FACE") != 0)) {
    return false;
  }
  strcpy(ordem.pedido, pedido);
  strcpy(ordem.acesso, acesso);
  ordem.duracao = duracao->valueint;
  return true;
}

bool topicoIgual(esp_mqtt_event_handle_t evento, const char* esperado) {
  return evento->topic && evento->topic_len == strlen(esperado) &&
         memcmp(evento->topic, esperado, evento->topic_len) == 0;
}

int digitoHex(char valor) {
  if (valor >= '0' && valor <= '9') return valor - '0';
  if (valor >= 'a' && valor <= 'f') return valor - 'a' + 10;
  return -1;
}

bool lerRespostaQr(const cJSON* json, RespostaQr& resposta) {
  const cJSON* versao = cJSON_GetObjectItemCaseSensitive(json, "schemaVersion");
  const cJSON* renovacao = cJSON_GetObjectItemCaseSensitive(json, "refreshAfterSeconds");
  const char* terminal = textoJson(json, "terminalId");
  const char* pedido = textoJson(json, "requestId");
  const char* bitmap = textoJson(json, "bitmap");
  const int64_t emitido = lerUtc(textoJson(json, "occurredAt"));
  resposta.vence = lerUtc(textoJson(json, "expiresAt"));
  if (!cJSON_IsNumber(versao) || versao->valuedouble != 1 ||
      !terminal || strcmp(terminal, MQTT_TERMINAL_ID) != 0 ||
      !uuidValido(pedido) || !uuidValido(textoJson(json, "eventId")) ||
      !emitido || resposta.vence - emitido != 20000 ||
      !cJSON_IsNumber(renovacao) || renovacao->valuedouble != 10 ||
      !bitmap || strlen(bitmap) != QR_BYTES * 2) return false;

  for (int i = 0; i < QR_BYTES; ++i) {
    const int alto = digitoHex(bitmap[i * 2]);
    const int baixo = digitoHex(bitmap[i * 2 + 1]);
    if (alto < 0 || baixo < 0) return false;
    resposta.bitmap[i] = (alto << 4) | baixo;
  }
  if (resposta.bitmap[QR_BYTES - 1] & 0x7f) return false;
  strcpy(resposta.pedido, pedido);
  resposta.renovar = emitido + 10000;
  return true;
}

void registrarDesconexao() {
  conectado = false;
  falhaEm = millis();
  desconectado = true;
  xQueueReset(ordens);
  xQueueReset(respostasQr);
}

void eventoMqtt(void*, esp_event_base_t, int32_t tipo, void* dados) {
  auto evento = static_cast<esp_mqtt_event_handle_t>(dados);
  switch (tipo) {
    case MQTT_EVENT_CONNECTED:
      desconectado = false;
      confirmadas = 0;
      assinaturas[0] = esp_mqtt_client_subscribe(mqtt, topicoOrdem, 1);
      assinaturas[1] = esp_mqtt_client_subscribe(mqtt, topicoDecisao, 1);
      assinaturas[2] = esp_mqtt_client_subscribe(mqtt, topicoQr, 1);
      if (assinaturas[0] < 0 || assinaturas[1] < 0 || assinaturas[2] < 0) registrarDesconexao();
      break;
    case MQTT_EVENT_SUBSCRIBED:
      for (unsigned i = 0; i < 3; ++i) {
        if (evento->msg_id != assinaturas[i]) continue;
        if (!evento->data || evento->data_len < 1 || evento->data[0] != 1) {
          registrarDesconexao();
          return;
        }
        confirmadas |= 1u << i;
      }
      if (confirmadas == 7 && !desconectado) {
        conectado = true;
        ++sessoes;
        Serial.println("[MQTT] Conectado, assinaturas QoS 1 confirmadas.");
      }
      break;
    case MQTT_EVENT_DISCONNECTED:
      registrarDesconexao();
      break;
    case MQTT_EVENT_ERROR:
      Serial.println("[MQTT] Falha de conexao. Confira rede, hora, CA e credenciais.");
      break;
    case MQTT_EVENT_DATA: {
      if (!conectado || evento->retain || evento->qos != 1 ||
          evento->current_data_offset != 0 || evento->data_len != evento->total_data_len ||
          evento->data_len <= 0 || evento->data_len > LIMITE_JSON) return;
      const bool nfc = topicoIgual(evento, topicoDecisao);
      const bool qr = topicoIgual(evento, topicoQr);
      if (!nfc && !qr && !topicoIgual(evento, topicoOrdem)) return;
      char texto[LIMITE_JSON + 1];
      memcpy(texto, evento->data, evento->data_len);
      texto[evento->data_len] = '\0';
      if (strlen(texto) != evento->data_len) return;
      cJSON* json = cJSON_ParseWithLengthOpts(texto, evento->data_len + 1, nullptr, true);
      if (qr) {
        RespostaQr resposta{};
        if (lerRespostaQr(json, resposta)) xQueueSend(respostasQr, &resposta, 0);
      } else {
        MensagemOrdem mensagem{};
        mensagem.nfc = nfc;
        if (lerOrdem(json, mensagem)) xQueueSend(ordens, &mensagem, 0);
      }
      cJSON_Delete(json);
      break;
    }
  }
}

void tarefaRede(void*) {
  bool iniciouSntp = false;
  bool iniciouMqtt = false;
  unsigned intervalo = 1000;
  unsigned long ultimaTentativa = 0;
  for (;;) {
    if (WiFi.status() == WL_CONNECTED) {
      if (!iniciouSntp) {
        esp_sntp_set_time_sync_notification_cb([](timeval*) { relogioSincronizado = true; });
        configTime(0, 0, "pool.ntp.org", "time.google.com");
        iniciouSntp = true;
      }
      if (!iniciouMqtt && relogioSincronizado && millis() - ultimaTentativa >= 1000) {
        ultimaTentativa = millis();
        iniciouMqtt = esp_mqtt_client_start(mqtt) == ESP_OK;
      }
      if (conectado) intervalo = 1000;
      if (iniciouMqtt && desconectado && millis() - falhaEm >= intervalo) {
        ultimaTentativa = millis();
        desconectado = false;
        conectado = false;
        esp_mqtt_client_stop(mqtt);
        iniciouMqtt = esp_mqtt_client_start(mqtt) == ESP_OK;
        intervalo = min(30000u, intervalo * 2);
      }
    }
    Publicacao mensagem;
    if (xQueueReceive(publicacoes, &mensagem, pdMS_TO_TICKS(50)) == pdTRUE && conectado) {
      esp_mqtt_client_enqueue(mqtt, mensagem.topico, mensagem.corpo,
                              0, 1, 0, true);
    }
  }
}

bool publicar(const char* sufixo, const char* evento, int64_t horario, const char* campos) {
  if (!conectado) return false;
  Publicacao mensagem{};
  char utc[25];
  formatarUtc(horario, utc);
  snprintf(mensagem.topico, sizeof(mensagem.topico), "access/v1/terminals/%s/%s", MQTT_TERMINAL_ID, sufixo);
  const int tamanho = snprintf(mensagem.corpo, sizeof(mensagem.corpo),
    "{\"schemaVersion\":1,\"terminalId\":\"%s\",\"eventId\":\"%s\",\"occurredAt\":\"%s\"%s}",
    MQTT_TERMINAL_ID, evento, utc, campos);
  return tamanho > 0 && tamanho < sizeof(mensagem.corpo) &&
         xQueueSend(publicacoes, &mensagem, 0) == pdTRUE;
}

bool publicarEstado(const char* sufixo, const char* campos) {
  char evento[37];
  gerarUuid(evento);
  return publicar(sufixo, evento, agoraUtc(), campos);
}

int64_t fimRegistro(const Registro& registro) {
  return registro.ordem.vence + PRAZO_ACK_MS;
}

void publicarAck(const Registro& registro, int64_t agora) {
  if (registro.resultado == INICIADO || agora > fimRegistro(registro)) return;
  const char* resultado = registro.resultado == UNLOCKED ? "UNLOCKED" :
                          registro.resultado == ERROR ? "ERROR" : "EXPIRED";
  char campos[220];
  const int tamanho = snprintf(campos, sizeof(campos),
    ",\"requestId\":\"%s\",\"accessLogId\":\"%s\",\"result\":\"%s\"",
    registro.ordem.pedido, registro.ordem.acesso, resultado);
  if (registro.aceite) {
    char utc[25];
    formatarUtc(registro.aceite, utc);
    snprintf(campos + tamanho, sizeof(campos) - tamanho, ",\"acceptedAt\":\"%s\"", utc);
  }
  publicar("door/ack", registro.evento, registro.conclusao, campos);
}

void chaveRegistro(int slot, char (&chave)[8]) {
  snprintf(chave, sizeof(chave), "ack%d", slot);
}

bool salvar(int slot, const Registro& registro) {
  char chave[8];
  chaveRegistro(slot, chave);
  if (memoria.putBytes(chave, &registro, sizeof(registro)) != sizeof(registro)) {
    Serial.println("[MQTT] Falha ao gravar registro de abertura.");
    return false;
  }
  registros[slot] = registro;
  return true;
}

bool processarOrdem(const Ordem& ordem, int64_t agora) {
  if (agora < ordem.emitida || agora > ordem.vence + PRAZO_ACK_MS) return false;
  int livre = -1;
  for (int i = 0; i < TOTAL_REGISTROS; ++i) {
    if (strcmp(registros[i].ordem.pedido, ordem.pedido) == 0 && agora <= fimRegistro(registros[i])) {
      publicarAck(registros[i], agora);
      return false;
    }
    if (i != ciclo && agora > fimRegistro(registros[i]) && livre == -1) livre = i;
  }
  if (livre < 0) return false;

  Registro registro{};
  registro.ordem = ordem;
  gerarUuid(registro.evento);
  if (agora >= ordem.vence) {
    registro.resultado = EXPIRED;
  } else {
    registro.aceite = agora;
    registro.resultado = ciclo != -1 || recuperacao ? ERROR : INICIADO;
  }
  if (registro.resultado != INICIADO) {
    registro.conclusao = agora;
    if (salvar(livre, registro)) publicarAck(registro, agora);
    return false;
  }
  if (!salvar(livre, registro)) return false;
  if (memoria.putBool(CHAVE_CICLO, true) != 1) {
    recuperacao = true;
    return false;
  }
  ciclo = livre;
  return true;
}
}

void iniciarMqttPorta() {
  if (!WIFI_SSID[0] || !MQTT_HOST[0] || strlen(MQTT_SENHA) < 16 ||
      !uuidValido(MQTT_TERMINAL_ID) || !MQTT_CA[0]) {
    Serial.println("[MQTT] Preencha mqtt_config.h. Acionamento desabilitado.");
    return;
  }
  if (!memoria.begin("mqtt-porta", false)) {
    Serial.println("[MQTT] NVS indisponivel. Acionamento desabilitado.");
    return;
  }
  recuperacao = memoria.getBool(CHAVE_CICLO, false);
  if (recuperacao) Serial.println("[MQTT] Ciclo interrompido. Verifique a posicao da porta em bancada.");
  for (int i = 0; i < TOTAL_REGISTROS; ++i) {
    char chave[8];
    chaveRegistro(i, chave);
    if (memoria.getBytesLength(chave) == sizeof(Registro)) memoria.getBytes(chave, &registros[i], sizeof(Registro));
  }
  ordens = xQueueCreate(8, sizeof(MensagemOrdem));
  respostasQr = xQueueCreate(4, sizeof(RespostaQr));
  publicacoes = xQueueCreate(TOTAL_REGISTROS + 8, sizeof(Publicacao));
  if (!ordens || !respostasQr || !publicacoes) return;
  snprintf(topicoOrdem, sizeof(topicoOrdem), "access/v1/terminals/%s/door/command", MQTT_TERMINAL_ID);
  snprintf(topicoDecisao, sizeof(topicoDecisao), "access/v1/terminals/%s/access/decision", MQTT_TERMINAL_ID);
  snprintf(topicoQr, sizeof(topicoQr), "access/v1/terminals/%s/qr/display", MQTT_TERMINAL_ID);
  snprintf(clientId, sizeof(clientId), "esp32-%s", MQTT_TERMINAL_ID);

  esp_mqtt_client_config_t config{};
  config.broker.address.hostname = MQTT_HOST;
  config.broker.address.port = MQTT_PORTA;
  config.broker.address.transport = MQTT_TRANSPORT_OVER_SSL;
  config.broker.verification.certificate = MQTT_CA;
  config.credentials.username = "esp32";
  config.credentials.authentication.password = MQTT_SENHA;
  config.credentials.client_id = clientId;
  config.session.protocol_ver = MQTT_PROTOCOL_V_3_1_1;
  config.network.disable_auto_reconnect = true;
  config.buffer.size = LIMITE_JSON + 128;
  mqtt = esp_mqtt_client_init(&config);
  if (!mqtt || esp_mqtt_client_register_event(mqtt, MQTT_EVENT_ANY, eventoMqtt, nullptr) != ESP_OK) return;

  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.begin(WIFI_SSID, WIFI_SENHA);
  xTaskCreate(tarefaRede, "mqtt-porta", 4096, nullptr, 1, nullptr);
}

bool solicitarAcessoNfc(const unsigned char* uid, unsigned int tamanho) {
  if (!conectado || !relogioSincronizado || ciclo != -1 || recuperacao ||
      pedidoNfc.id[0] || (tamanho != 4 && tamanho != 7 && tamanho != 10)) return false;
  constexpr char hex[] = "0123456789ABCDEF";
  char tag[21]{};
  for (unsigned i = 0; i < tamanho; ++i) {
    tag[i * 2] = hex[uid[i] >> 4];
    tag[i * 2 + 1] = hex[uid[i] & 0x0f];
  }
  PedidoNfc pedido{};
  gerarUuid(pedido.id);
  pedido.inicio = millis();
  pedido.sessao = sessoes;
  const int64_t utc = agoraUtc();
  pedido.vence = utc + PRAZO_ACEITE_MS;
  char campos[100];
  snprintf(campos, sizeof(campos), ",\"requestId\":\"%s\",\"uid\":\"%s\"", pedido.id, tag);
  char evento[37];
  gerarUuid(evento);
  if (!publicar("access/request", evento, utc, campos)) return false;
  pedidoNfc = pedido;
  return true;
}

unsigned long atualizarMqttPorta(bool presente, bool& nfcNegado) {
  nfcNegado = false;
  if (!conectado || !relogioSincronizado) {
    nfcNegado = pedidoNfc.id[0] && ciclo == -1;
    pedidoNfc = {};
    return 0;
  }
  static unsigned sessaoAnterior = 0;
  static unsigned long ultimoStatus = 0;
  static unsigned long ultimaPresenca = 0;
  static bool presencaAnterior = false;
  const unsigned sessao = sessoes;
  const unsigned long agora = millis();
  const bool novaSessao = sessao != sessaoAnterior;
  const int64_t utc = agoraUtc();
  if (pedidoNfc.id[0] && (pedidoNfc.sessao != sessao || agora - pedidoNfc.inicio >= PRAZO_ACEITE_MS ||
                        utc >= pedidoNfc.vence)) {
    nfcNegado = ciclo == -1;
    pedidoNfc = {};
  }
  if ((novaSessao || agora - ultimoStatus >= 10000) && publicarEstado("status", "")) ultimoStatus = agora;
  if ((novaSessao || presente != presencaAnterior || (presente && agora - ultimaPresenca >= 2000)) &&
      publicarEstado("presence", presente ? ",\"detected\":true" : ",\"detected\":false")) {
    presencaAnterior = presente;
    ultimaPresenca = agora;
  }
  if (novaSessao) {
    for (const Registro& registro : registros) publicarAck(registro, utc);
  }
  sessaoAnterior = sessao;

  MensagemOrdem mensagem{};
  if (xQueueReceive(ordens, &mensagem, 0) != pdTRUE) return 0;
  const Ordem& ordem = mensagem.ordem;
  if (mensagem.nfc) {
    if (utc < ordem.emitida || utc >= ordem.vence) return 0;
    if (strcmp(ordem.pedido, pedidoNfc.id) != 0 || ordem.vence != pedidoNfc.vence) {
      for (const Registro& registro : registros) {
        if (strcmp(ordem.pedido, registro.ordem.pedido) == 0 &&
            strcmp(ordem.acesso, registro.ordem.acesso) == 0) publicarAck(registro, utc);
      }
      return 0;
    }
    pedidoNfc = {};
    if (!mensagem.autorizada) {
      nfcNegado = ciclo == -1;
      return 0;
    }
  }
  return processarOrdem(ordem, utc) ? ordem.duracao : 0;
}

AtualizacaoQr atualizarQrMqtt(bool habilitado, uint8_t (&bitmap)[QR_BYTES]) {
  static struct {
    char id[37];
    unsigned long inicio;
  } pedido{};
  static int64_t validade = 0;
  static int64_t renovar = 0;
  static unsigned sessaoAnterior = 0;
  const unsigned sessao = sessoes;
  AtualizacaoQr atualizacao = AtualizacaoQr::Nenhuma;
  if (!habilitado || !conectado || !relogioSincronizado || sessao != sessaoAnterior) {
    if (habilitado && validade) atualizacao = AtualizacaoQr::Limpar;
    validade = 0;
    renovar = 0;
    pedido = {};
    sessaoAnterior = sessao;
  }
  if (!habilitado || !conectado || !relogioSincronizado) return atualizacao;

  const int64_t utc = agoraUtc();
  const unsigned long agora = millis();
  if (validade && utc >= validade) {
    validade = 0;
    atualizacao = AtualizacaoQr::Limpar;
  }
  if (pedido.id[0] && agora - pedido.inicio >= PRAZO_ACEITE_MS) pedido = {};

  RespostaQr resposta{};
  while (xQueueReceive(respostasQr, &resposta, 0) == pdTRUE) {
    if (strcmp(pedido.id, resposta.pedido) != 0 || utc >= resposta.vence) continue;
    memcpy(bitmap, resposta.bitmap, sizeof(resposta.bitmap));
    validade = resposta.vence;
    renovar = resposta.renovar;
    pedido = {};
    return AtualizacaoQr::Exibir;
  }

  if (!pedido.id[0] && utc >= renovar) {
    gerarUuid(pedido.id);
    pedido.inicio = agora;
    char campos[64];
    snprintf(campos, sizeof(campos), ",\"requestId\":\"%s\"", pedido.id);
    if (!publicarEstado("qr/request", campos)) pedido = {};
  }
  return atualizacao;
}

void confirmarAberturaMqtt() {
  if (ciclo < 0) return;
  Registro registro = registros[ciclo];
  registro.conclusao = agoraUtc();
  if (registro.conclusao < registro.aceite || registro.conclusao - registro.aceite > PRAZO_ACK_MS) return;
  registro.resultado = UNLOCKED;
  if (salvar(ciclo, registro)) publicarAck(registro, registro.conclusao);
}

void confirmarFechamentoMqtt() {
  if (ciclo < 0) return;
  if (memoria.putBool(CHAVE_CICLO, false) != 1) recuperacao = true;
  ciclo = -1;
}
