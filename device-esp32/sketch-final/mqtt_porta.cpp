#include "mqtt_porta.h"

#include <Arduino.h>
#include <Preferences.h>
#include <cJSON.h>
#include <esp_random.h>
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
constexpr size_t LIMITE_QUADRO = 3072;
constexpr unsigned long INTERVALO_SERIAL_MS = 1000;
constexpr unsigned long TIMEOUT_SERIAL_MS = 3000;
constexpr char PREFIXO_SERIAL[] = "@AC ";

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
  const char* rota;
  char corpo[512];
};

struct ConfirmacaoPublicacao {
  uint32_t id;
  unsigned long enviadaEm;
};

Preferences memoria;
Registro registros[TOTAL_REGISTROS]{};
int ciclo = -1;
bool recuperacao = false;
QueueHandle_t ordens;
QueueHandle_t respostasQr;
QueueHandle_t publicacoes;
bool serialIniciada = false;
bool conectado = false;
bool sessaoMqttEncerrada = false;
unsigned sessoes = 0;
char bootId[37]{};
char sessionId[37]{};
unsigned long ultimoLink = 0;
unsigned long ultimoControle = 0;
uint32_t ultimoIdRecebido = 0;
uint32_t ultimoIdEnviado = 0;
ConfirmacaoPublicacao confirmacoes[8]{};
char entradaSerial[LIMITE_QUADRO + 2];
size_t tamanhoEntrada = 0;
bool descartarLinha = false;
char saidaSerial[768];
size_t tamanhoSaida = 0;

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
  // A inicializacao do transporte fixa o fuso de mktime em UTC.
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

void limparSessaoMqtt() {
  conectado = false;
  xQueueReset(ordens);
  xQueueReset(respostasQr);
  xQueueReset(publicacoes);
  memset(confirmacoes, 0, sizeof(confirmacoes));
  tamanhoSaida = 0;
}

bool enfileirarQuadro(int tamanho) {
  if (tamanho <= 0 || static_cast<size_t>(tamanho) >= sizeof(saidaSerial)) return false;
  tamanhoSaida = tamanho;
  return true;
}

bool inteiroJson(const cJSON* json, const char* campo, double minimo, double maximo,
                  int64_t& resultado) {
  const cJSON* item = cJSON_GetObjectItemCaseSensitive(json, campo);
  if (!cJSON_IsNumber(item) || !(item->valuedouble >= minimo && item->valuedouble <= maximo)) return false;
  resultado = static_cast<int64_t>(item->valuedouble);
  return item->valuedouble == resultado;
}

void responderEntrega(uint32_t id, const char* motivo) {
  enfileirarQuadro(snprintf(saidaSerial, sizeof(saidaSerial),
    "\n@AC {\"v\":1,\"type\":\"ack\",\"sessionId\":\"%s\",\"id\":%lu,"
    "\"forType\":\"deliver\",\"result\":\"%s\"%s%s%s}\n",
    sessionId, static_cast<unsigned long>(id), motivo ? "rejected" : "accepted",
    motivo ? ",\"reason\":\"" : "", motivo ? motivo : "", motivo ? "\"" : ""));
}

const char* enfileirarEntrega(const cJSON* quadro) {
  if (!conectado) return "unavailable";
  const char* rota = textoJson(quadro, "route");
  const cJSON* payload = cJSON_GetObjectItemCaseSensitive(quadro, "payload");
  if (!rota || !cJSON_IsObject(payload)) return "invalid";

  char* compacto = cJSON_PrintUnformatted(payload);
  const bool tamanhoValido = compacto && strlen(compacto) <= LIMITE_JSON;
  cJSON_free(compacto);
  if (!tamanhoValido) return "invalid";

  if (strcmp(rota, "qr/display") == 0) {
    RespostaQr resposta{};
    if (!lerRespostaQr(payload, resposta)) return "invalid";
    return xQueueSend(respostasQr, &resposta, 0) == pdTRUE ? nullptr : "queue_full";
  }

  MensagemOrdem mensagem{};
  mensagem.nfc = strcmp(rota, "access/decision") == 0;
  if ((!mensagem.nfc && strcmp(rota, "door/command") != 0) || !lerOrdem(payload, mensagem)) {
    return "invalid";
  }
  return xQueueSend(ordens, &mensagem, 0) == pdTRUE ? nullptr : "queue_full";
}

void receberWelcome(const cJSON* quadro, const char* sessao, unsigned long agora) {
  const char* terminal = textoJson(quadro, "terminalId");
  const char* boot = textoJson(quadro, "bootId");
  int64_t utcMs;
  if (!terminal || strcmp(terminal, MQTT_TERMINAL_ID) != 0 ||
      !boot || strcmp(boot, bootId) != 0 ||
      !inteiroJson(quadro, "utcMs", 1577836800000.0, 4102444799999.0, utcMs)) return;

  if (strcmp(sessao, sessionId) != 0) {
    if (conectado) return;
    const timeval hora{static_cast<time_t>(utcMs / 1000),
                       static_cast<suseconds_t>(utcMs % 1000 * 1000)};
    if (settimeofday(&hora, nullptr) != 0) return;
    limparSessaoMqtt();
    strcpy(sessionId, sessao);
    sessaoMqttEncerrada = false;
    ultimoIdRecebido = 0;
    ultimoIdEnviado = 0;
    ultimoLink = agora;
    ultimoControle = agora;
  }
  enfileirarQuadro(snprintf(saidaSerial, sizeof(saidaSerial),
    "\n@AC {\"v\":1,\"type\":\"ready\",\"sessionId\":\"%s\"}\n", sessionId));
}

void processarQuadro(const cJSON* quadro, unsigned long agora) {
  int64_t versao;
  const char* tipo = textoJson(quadro, "type");
  const char* sessao = textoJson(quadro, "sessionId");
  if (!tipo || !uuidValido(sessao) || !inteiroJson(quadro, "v", 1, 1, versao)) return;
  if (strcmp(tipo, "welcome") == 0) {
    receberWelcome(quadro, sessao, agora);
    return;
  }
  if (strcmp(sessao, sessionId) != 0) return;
  if (strcmp(tipo, "link") == 0) {
    const cJSON* pronto = cJSON_GetObjectItemCaseSensitive(quadro, "mqttReady");
    if (!cJSON_IsBool(pronto)) return;
    ultimoLink = agora;
    if (cJSON_IsTrue(pronto) && !conectado && !sessaoMqttEncerrada) {
      ++sessoes;
      conectado = true;
      Serial.println("[USB] Ponte MQTT pronta.");
    } else if (cJSON_IsFalse(pronto) && conectado) {
      limparSessaoMqtt();
      sessaoMqttEncerrada = true;
      Serial.println("[USB] Ponte MQTT indisponivel.");
    }
    return;
  }

  int64_t id;
  if (!inteiroJson(quadro, "id", 1, UINT32_MAX, id)) return;
  if (strcmp(tipo, "deliver") == 0 && id > ultimoIdRecebido) {
    ultimoIdRecebido = id;
    responderEntrega(id, enfileirarEntrega(quadro));
  } else if (strcmp(tipo, "ack") == 0) {
    const char* origem = textoJson(quadro, "forType");
    const char* resultado = textoJson(quadro, "result");
    if (!origem || strcmp(origem, "publish") != 0 || !resultado ||
        (strcmp(resultado, "published") != 0 && strcmp(resultado, "rejected") != 0)) return;
    for (ConfirmacaoPublicacao& item : confirmacoes) {
      if (item.id == id) {
        item = {};
        break;
      }
    }
  }
}

bool profundidadeValida(const char* json) {
  int nivel = 0;
  bool emTexto = false;
  for (const char* p = json; *p; ++p) {
    if (emTexto && *p == '\\' && p[1]) {
      ++p;
    } else if (*p == '"') {
      emTexto = !emTexto;
    } else if (!emTexto && (*p == '{' || *p == '[')) {
      if (++nivel > 16) return false;
    } else if (!emTexto && (*p == '}' || *p == ']')) {
      --nivel;
    }
  }
  return true;
}

void receberSerial(unsigned long agora) {
  // Limita o trabalho por chamada para dar tempo ao loop do motor.
  for (unsigned restantes = 512; restantes && Serial.available() && !tamanhoSaida; --restantes) {
    const int byteLido = Serial.read();
    if (byteLido < 0) break;
    if (byteLido == '\n') {
      if (tamanhoEntrada && entradaSerial[tamanhoEntrada - 1] == '\r') --tamanhoEntrada;
      entradaSerial[tamanhoEntrada] = '\0';
      constexpr size_t inicioJson = sizeof(PREFIXO_SERIAL) - 1;
      if (!descartarLinha && tamanhoEntrada > inicioJson && tamanhoEntrada <= LIMITE_QUADRO &&
          memcmp(entradaSerial, PREFIXO_SERIAL, inicioJson) == 0 &&
          profundidadeValida(entradaSerial + inicioJson)) {
        cJSON* quadro = cJSON_ParseWithLengthOpts(
          entradaSerial + inicioJson, tamanhoEntrada - inicioJson + 1, nullptr, true);
        if (cJSON_IsObject(quadro)) processarQuadro(quadro, agora);
        cJSON_Delete(quadro);
      }
      tamanhoEntrada = 0;
      descartarLinha = false;
    } else if (!descartarLinha) {
      if (byteLido == '\0' || tamanhoEntrada == sizeof(entradaSerial) - 1) {
        descartarLinha = true;
      } else {
        entradaSerial[tamanhoEntrada++] = static_cast<char>(byteLido);
      }
    }
  }
}

void prepararPublicacao(unsigned long agora) {
  ConfirmacaoPublicacao* livre = nullptr;
  for (ConfirmacaoPublicacao& item : confirmacoes) {
    if (item.id && agora - item.enviadaEm >= TIMEOUT_SERIAL_MS) item = {};
    if (!item.id && !livre) livre = &item;
  }
  if (!livre) return;
  Publicacao mensagem{};
  if (xQueueReceive(publicacoes, &mensagem, 0) != pdTRUE) return;
  const uint32_t id = ++ultimoIdEnviado;
  if (enfileirarQuadro(snprintf(saidaSerial, sizeof(saidaSerial),
      "\n@AC {\"v\":1,\"type\":\"publish\",\"sessionId\":\"%s\",\"id\":%lu,"
      "\"route\":\"%s\",\"payload\":%s}\n",
      sessionId, static_cast<unsigned long>(id), mensagem.rota, mensagem.corpo))) {
    *livre = {id, agora};
  }
}

void atualizarSerial() {
  if (!serialIniciada) return;
  const unsigned long agora = millis();
  if (sessionId[0] && agora - ultimoLink >= TIMEOUT_SERIAL_MS) {
    limparSessaoMqtt();
    sessionId[0] = '\0';
    ultimoControle = agora - INTERVALO_SERIAL_MS;
    Serial.println("[USB] Sessao da ponte expirou.");
  }
  if (!tamanhoSaida) receberSerial(agora);
  if (!tamanhoSaida && agora - ultimoControle >= INTERVALO_SERIAL_MS) {
    if (sessionId[0]) {
      enfileirarQuadro(snprintf(saidaSerial, sizeof(saidaSerial),
        "\n@AC {\"v\":1,\"type\":\"heartbeat\",\"sessionId\":\"%s\"}\n", sessionId));
    } else {
      enfileirarQuadro(snprintf(saidaSerial, sizeof(saidaSerial),
        "\n@AC {\"v\":1,\"type\":\"hello\",\"terminalId\":\"%s\",\"bootId\":\"%s\"}\n",
        MQTT_TERMINAL_ID, bootId));
    }
    ultimoControle = agora;
  }
  if (!tamanhoSaida && conectado) prepararPublicacao(agora);
  if (tamanhoSaida && Serial.availableForWrite() >= static_cast<int>(tamanhoSaida)) {
    Serial.write(reinterpret_cast<const uint8_t*>(saidaSerial), tamanhoSaida);
    tamanhoSaida = 0;
  }
}

bool publicar(const char* sufixo, const char* evento, int64_t horario, const char* campos) {
  if (!conectado) return false;
  Publicacao mensagem{};
  char utc[25];
  formatarUtc(horario, utc);
  mensagem.rota = sufixo;
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
  if (!uuidValido(MQTT_TERMINAL_ID)) {
    Serial.println("[USB] Configure MQTT_TERMINAL_ID. Acionamento desabilitado.");
    return;
  }
  if (!memoria.begin("mqtt-porta", false)) {
    Serial.println("[USB] NVS indisponivel. Acionamento desabilitado.");
    return;
  }
  recuperacao = memoria.getBool(CHAVE_CICLO, false);
  if (recuperacao) Serial.println("[USB] Ciclo interrompido. Verifique a posicao da porta em bancada.");
  for (int i = 0; i < TOTAL_REGISTROS; ++i) {
    char chave[8];
    chaveRegistro(i, chave);
    if (memoria.getBytesLength(chave) == sizeof(Registro)) memoria.getBytes(chave, &registros[i], sizeof(Registro));
  }
  ordens = xQueueCreate(8, sizeof(MensagemOrdem));
  respostasQr = xQueueCreate(4, sizeof(RespostaQr));
  publicacoes = xQueueCreate(TOTAL_REGISTROS + 8, sizeof(Publicacao));
  if (!ordens || !respostasQr || !publicacoes) {
    Serial.println("[USB] Memoria insuficiente para criar filas.");
    if (ordens) vQueueDelete(ordens);
    if (respostasQr) vQueueDelete(respostasQr);
    if (publicacoes) vQueueDelete(publicacoes);
    memoria.end();
    return;
  }
  setenv("TZ", "UTC0", 1);
  tzset();
  gerarUuid(bootId);
  ultimoControle = millis() - INTERVALO_SERIAL_MS;
  serialIniciada = true;
  Serial.println("[USB] Aguardando ponte serial.");
}

bool solicitarAcessoNfc(const unsigned char* uid, unsigned int tamanho) {
  if (!conectado || ciclo != -1 || recuperacao ||
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
  atualizarSerial();
  nfcNegado = false;
  if (!conectado) {
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
  if (!habilitado || !conectado || sessao != sessaoAnterior) {
    if (habilitado && validade) atualizacao = AtualizacaoQr::Limpar;
    validade = 0;
    renovar = 0;
    pedido = {};
    sessaoAnterior = sessao;
  }
  if (!habilitado || !conectado) return atualizacao;

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
