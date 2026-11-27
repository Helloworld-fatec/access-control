#pragma once

#include <stdint.h>

constexpr unsigned long TEMPO_ABERTO_MAXIMO = 3000;
constexpr int QR_MODULOS = 21;
constexpr int QR_BYTES = (QR_MODULOS * QR_MODULOS + 7) / 8;
enum class AtualizacaoQr { Nenhuma, Exibir, Limpar };

void iniciarMqttPorta();
bool solicitarAcessoNfc(const unsigned char* uid, unsigned int tamanho);
unsigned long atualizarMqttPorta(bool presente, bool& nfcNegado);
AtualizacaoQr atualizarQrMqtt(bool habilitado, uint8_t (&bitmap)[QR_BYTES]);
void confirmarAberturaMqtt();
void confirmarFechamentoMqtt();
