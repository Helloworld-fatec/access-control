#!/bin/sh
set -eu

data=/mosquitto/data
public=/mqtt-ca
umask 077
mkdir -p "$data/private" "$public"
chmod 755 "$public"

require_password() {
  if [ "${#2}" -lt 16 ]; then
    echo "$1 deve ter ao menos 16 caracteres" >&2
    exit 1
  fi
}

device_acl() {
  account=$1
  uuid=$2
  password=$3
  if [ -z "$uuid" ]; then return; fi
  if ! printf '%s\n' "$uuid" | grep -Eq '^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$'; then
    echo "UUID MQTT inválido para $account" >&2
    exit 1
  fi
  require_password "$account" "$password"
  mosquitto_passwd -b "$data/passwd" "$account" "$password"
  prefix="access/v1/terminals/$uuid"
  printf '\nuser %s\n' "$account" >> "$data/acl"
  for suffix in status presence door/state access/request door/ack nfc/enroll/ack; do
    printf 'topic write %s/%s\n' "$prefix" "$suffix" >> "$data/acl"
  done
  for suffix in access/decision door/command nfc/enroll; do
    printf 'topic read %s/%s\n' "$prefix" "$suffix" >> "$data/acl"
  done
}

require_password MQTT_BACKEND_PASSWORD "${MQTT_BACKEND_PASSWORD:-}"
if [ -n "${ESP32_TERMINAL_ID:-}" ] && [ "$ESP32_TERMINAL_ID" = "${MQTT_SIMULATOR_TERMINAL_ID:-}" ]; then
  echo 'Use UUIDs distintos para a placa e o simulador' >&2
  exit 1
fi
mosquitto_passwd -b -c "$data/passwd" backend "$MQTT_BACKEND_PASSWORD"
{
  printf 'user backend\ntopic read $SYS/broker/version\n'
  for suffix in status presence door/state access/request door/ack nfc/enroll/ack; do
    printf 'topic read access/v1/terminals/+/%s\n' "$suffix"
  done
  for suffix in access/decision door/command nfc/enroll; do
    printf 'topic write access/v1/terminals/+/%s\n' "$suffix"
  done
} > "$data/acl"
device_acl esp32 "${ESP32_TERMINAL_ID:-}" "${MQTT_ESP32_PASSWORD:-}"
device_acl simulator "${MQTT_SIMULATOR_TERMINAL_ID:-}" "${MQTT_SIMULATOR_PASSWORD:-}"

san=DNS:mosquitto
if [ -n "${MQTT_LAN_HOST:-}" ]; then
  case "$MQTT_LAN_HOST" in
    *[!0-9A-Za-z.-]*) echo 'Informe um DNS ou IPv4 em MQTT_LAN_HOST' >&2; exit 1 ;;
    *[!0-9.]*) san="$san,DNS:$MQTT_LAN_HOST" ;;
    *) san="$san,IP:$MQTT_LAN_HOST" ;;
  esac
fi
if [ ! -s "$data/private/ca.key" ] || [ ! -s "$data/private/ca.crt" ]; then
  openssl req -x509 -newkey rsa:2048 -nodes -sha256 -days 3650 \
    -subj '/CN=Access Control MQTT CA' -addext 'basicConstraints=critical,CA:TRUE' \
    -keyout "$data/private/ca.key" -out "$data/private/ca.crt"
fi
openssl req -new -newkey rsa:2048 -nodes -subj '/CN=mosquitto' \
  -keyout "$data/server.key" -out "$data/private/server.csr"
printf 'subjectAltName=%s\nextendedKeyUsage=serverAuth\n' "$san" > "$data/private/server.ext"
openssl x509 -req -in "$data/private/server.csr" -CA "$data/private/ca.crt" \
  -CAkey "$data/private/ca.key" -CAcreateserial -extfile "$data/private/server.ext" \
  -days 365 -sha256 -out "$data/server.crt"
cp "$data/private/ca.crt" "$public/ca.crt.tmp"
chmod 644 "$public/ca.crt.tmp"
mv "$public/ca.crt.tmp" "$public/ca.crt"
chown mosquitto:mosquitto "$data" "$data/passwd" "$data/acl" "$data/server.crt" "$data/server.key"
exec mosquitto -c /mosquitto/config/mosquitto.conf
