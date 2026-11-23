import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { performance } from 'node:perf_hooks';
import { checkServerIdentity } from 'node:tls';
import { pathToFileURL } from 'node:url';
import { connect } from 'mqtt';
import { SerialPort } from 'serialport';

const PREFIX = '@AC ';
const FRAME_LIMIT = 3072;
const PAYLOAD_LIMIT = 2048;
const HEARTBEAT_MS = 1000;
const TIMEOUT_MS = 3000;
const USB_BOOT_TIMEOUT_MS = 5000;
const RESET_PULSE_MS = 100;
const MAX_ID = 0xffffffff;
const MAX_PENDING = 32;
const UUID = /^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i;
const PUBLISH_ROUTES = new Set(['status', 'presence', 'access/request', 'qr/request', 'door/ack']);
const DELIVER_ROUTES = ['door/command', 'access/decision', 'qr/display'];
const mqttOptions = { qos: 1, retain: false };

function parseObject(text) {
  try {
    const value = JSON.parse(text);
    return value && typeof value === 'object' && !Array.isArray(value) ? value : null;
  } catch {
    return null;
  }
}

function frameIdValid(id) {
  return Number.isInteger(id) && id > 0 && id <= MAX_ID;
}

function createReader(onFrame, onLog) {
  const line = Buffer.alloc(FRAME_LIMIT + 1);
  const decoder = new TextDecoder('utf-8', { fatal: true });
  let length = 0;
  let discard = false;
  return {
    reset() {
      length = 0;
      discard = false;
    },
    read(chunk) {
      for (const byte of chunk) {
        if (byte !== 10) {
          if (byte === 0 || length === line.length) discard = true;
          if (!discard) line[length++] = byte;
          continue;
        }
        if (!discard && length && line[length - 1] === 13) length--;
        const text = !discard && length <= FRAME_LIMIT ? line.subarray(0, length) : null;
        length = 0;
        discard = false;
        if (!text?.length) continue;
        if (!text.subarray(0, PREFIX.length).equals(Buffer.from(PREFIX))) {
          onLog(text.toString());
          continue;
        }
        let frame;
        try {
          frame = parseObject(decoder.decode(text.subarray(PREFIX.length)));
        } catch {
          continue;
        }
        if (frame?.v === 1) onFrame(frame);
      }
    },
  };
}

export function startBridge({ serial, createClient, terminalId, log = console.log }) {
  const topicPrefix = `access/v1/terminals/${terminalId}/`;
  const subscriptions = DELIVER_ROUTES.map(route => topicPrefix + route);
  let session;
  let client;
  let mqttReady = false;
  let serialOpening = false;
  let serialConfigured = false;
  let serialOpenedBefore = false;
  let resetIfSilentAt = 0;
  let resetTimer;
  let nextSerialAttempt = 0;
  let nextMqttAttempt = 0;
  let lastControl = 0;
  let stopped = false;

  function send(frame) {
    if (!serialConfigured || !serial.isOpen || serial.writableLength > FRAME_LIMIT * 2) return false;
    const line = PREFIX + JSON.stringify({ v: 1, ...frame });
    if (Buffer.byteLength(line) > FRAME_LIMIT) return false;
    serial.write(line + '\n', error => {
      if (error && !stopped) log(`[USB] Falha na escrita: ${error.message}`);
    });
    return true;
  }

  function newSession(bootId) {
    return {
      bootId, id: randomUUID(), ready: false, lastHeartbeat: performance.now(),
      lastPublish: 0, lastDelivery: 0, pendingPublish: new Map(), pendingDelivery: new Map(),
    };
  }

  function sendControl() {
    if (!session) return;
    const sent = session.ready
      ? send({ type: 'link', sessionId: session.id, mqttReady })
      : send({
        type: 'welcome', sessionId: session.id, terminalId,
        bootId: session.bootId, utcMs: Date.now(),
      });
    if (sent) lastControl = performance.now();
  }

  function replyPublish(current, id, reason) {
    send({
      type: 'ack', sessionId: current.id, id, forType: 'publish',
      result: reason ? 'rejected' : 'published', ...(reason ? { reason } : {}),
    });
  }

  function handlePublish(frame, current) {
    if (!frameIdValid(frame.id) || frame.id <= current.lastPublish) return;
    current.lastPublish = frame.id;
    if (!mqttReady || !client?.connected) return replyPublish(current, frame.id, 'unavailable');
    const { route, payload } = frame;
    if (!PUBLISH_ROUTES.has(route) || payload?.terminalId !== terminalId) {
      return replyPublish(current, frame.id, 'invalid');
    }
    const body = JSON.stringify(payload);
    if (Buffer.byteLength(body) > PAYLOAD_LIMIT) return replyPublish(current, frame.id, 'invalid');
    if (current.pendingPublish.size >= MAX_PENDING) return replyPublish(current, frame.id, 'queue_full');
    current.pendingPublish.set(frame.id, performance.now());
    const connection = client;
    connection.publish(topicPrefix + route, body, mqttOptions, (error, packet) => {
      if (session !== current || client !== connection || !current.pendingPublish.delete(frame.id)) return;
      replyPublish(current, frame.id, error || (packet?.reasonCode ?? 0) >= 128 ? 'mqtt_error' : null);
    });
  }

  function handleFrame(frame) {
    if (frame.type === 'hello') {
      if (frame.terminalId !== terminalId || typeof frame.bootId !== 'string' || !UUID.test(frame.bootId)) return;
      resetIfSilentAt = 0;
      if (!session || session.bootId !== frame.bootId || session.ready) session = newSession(frame.bootId);
      sendControl();
      return;
    }
    const current = session;
    if (!current || frame.sessionId !== current.id) return;
    if (frame.type === 'ready') {
      if (!current.ready) log('[USB] Sessão serial pronta.');
      current.ready = true;
      current.lastHeartbeat = performance.now();
      sendControl();
      return;
    }
    if (!current.ready) return;
    if (frame.type === 'heartbeat') current.lastHeartbeat = performance.now();
    if (frame.type === 'publish') handlePublish(frame, current);
    if (frame.type === 'ack' && frame.forType === 'deliver' &&
        (frame.result === 'accepted' || frame.result === 'rejected') &&
        current.pendingDelivery.delete(frame.id) && frame.result === 'rejected') {
      log(`[USB] Entrega ${frame.id} recusada pelo ESP32.`);
    }
  }

  const reader = createReader(handleFrame, line => log(`[ESP32] ${line}`));
  serial.on('data', chunk => {
    if (serialConfigured) reader.read(chunk);
  });
  serial.on('close', () => {
    serialConfigured = false;
    resetIfSilentAt = 0;
    clearTimeout(resetTimer);
    session = undefined;
    reader.reset();
    nextSerialAttempt = performance.now() + HEARTBEAT_MS;
  });
  serial.on('error', error => log(`[USB] ${error.message}`));

  function disconnectMqtt(connection) {
    if (client !== connection) return;
    client = undefined;
    mqttReady = false;
    if (session) {
      session.pendingDelivery.clear();
      session.pendingPublish.clear();
      sendControl();
    }
    nextMqttAttempt = performance.now() + HEARTBEAT_MS;
    connection.end(true);
  }

  function connectMqtt() {
    const connection = createClient();
    client = connection;
    connection.on('error', error => {
      if (client !== connection) return;
      log(`[MQTT] ${error.message}`);
      disconnectMqtt(connection);
    });
    connection.on('close', () => disconnectMqtt(connection));
    connection.on('connect', () => {
      connection.subscribe(subscriptions, { qos: 1, rap: true, rh: 2 }, (error, grants) => {
        if (client !== connection) return;
        if (error || !subscriptions.every(topic => grants?.some(grant => grant.topic === topic && grant.qos === 1))) {
          log('[MQTT] O broker não confirmou as três assinaturas com QoS 1.');
          disconnectMqtt(connection);
          return;
        }
        mqttReady = true;
        if (session?.ready) session = newSession(session.bootId);
        sendControl();
        log('[MQTT] TLS conectado e assinaturas QoS 1 confirmadas.');
      });
    });
    connection.on('message', (topic, bytes, packet) => {
      if (client !== connection || !mqttReady || !session?.ready ||
          packet.retain || packet.qos !== 1 || bytes.length > PAYLOAD_LIMIT ||
          !subscriptions.includes(topic) || session.pendingDelivery.size >= MAX_PENDING) return;
      const payload = parseObject(bytes.toString());
      if (payload?.terminalId !== terminalId) return;
      const id = ++session.lastDelivery;
      if (send({ type: 'deliver', id, sessionId: session.id, route: topic.slice(topicPrefix.length), payload })) {
        session.pendingDelivery.set(id, performance.now());
      }
    });
  }

  function tick() {
    const now = performance.now();
    if (!serial.isOpen && !serialOpening && now >= nextSerialAttempt) {
      serialOpening = true;
      serial.open(error => {
        serialOpening = false;
        nextSerialAttempt = performance.now() + HEARTBEAT_MS;
        if (error) {
          if (!stopped) log(`[USB] ${error.message}`);
          return;
        }
        if (stopped) {
          serial.close();
          return;
        }
        // Libera GPIO0 e EN para que o botão EN inicie o firmware em flash.
        serial.set({ dtr: false, rts: false }, setError => {
          if (stopped || !serial.isOpen) return;
          if (setError) {
            log(`[USB] Falha ao liberar DTR e RTS: ${setError.message}`);
            serial.close();
            return;
          }
          serialConfigured = true;
          if (serialOpenedBefore) resetIfSilentAt = performance.now() + USB_BOOT_TIMEOUT_MS;
          serialOpenedBefore = true;
          log('[USB] Porta serial aberta. Aguardando hello.');
        });
      });
    }
    if (!client && now >= nextMqttAttempt) connectMqtt();
    if (serialConfigured && resetIfSilentAt && now >= resetIfSilentAt) {
      resetIfSilentAt = 0;
      log('[USB] Sem hello após reconectar. Tentando reset pelo RTS.');
      serial.set({ dtr: false, rts: true }, error => {
        if (stopped || !serial.isOpen) return;
        if (error) {
          log(`[USB] Não foi possível acionar RTS: ${error.message}`);
          return;
        }
        resetTimer = setTimeout(() => {
          if (stopped || !serial.isOpen) return;
          serial.set({ dtr: false, rts: false }, releaseError => {
            if (releaseError && !stopped && serial.isOpen) {
              log(`[USB] Falha ao liberar RTS: ${releaseError.message}`);
              serial.close();
            }
          });
        }, RESET_PULSE_MS);
      });
    }
    if (!session) return;
    if (now - session.lastHeartbeat >= TIMEOUT_MS) {
      session = undefined;
      log('[USB] Sessão expirada. Aguardando novo hello.');
      return;
    }
    if (now - lastControl >= HEARTBEAT_MS) sendControl();
    for (const pending of [session.pendingPublish, session.pendingDelivery]) {
      for (const [id, sentAt] of pending) {
        if (now - sentAt >= TIMEOUT_MS) pending.delete(id);
      }
    }
  }

  const timer = setInterval(tick, 100);
  tick();
  return () => {
    stopped = true;
    clearInterval(timer);
    clearTimeout(resetTimer);
    if (client) disconnectMqtt(client);
    if (serial.isOpen) serial.close();
  };
}

function main() {
  const terminalId = process.env.ESP32_TERMINAL_ID ?? '';
  const password = process.env.MQTT_ESP32_PASSWORD ?? '';
  if (!UUID.test(terminalId) || password.length < 16) {
    throw new Error('Preencha ESP32_TERMINAL_ID e MQTT_ESP32_PASSWORD no .env da ponte.');
  }
  const url = new URL(process.env.MQTT_URL || 'mqtts://127.0.0.1:8883');
  if (url.protocol !== 'mqtts:' || url.username || url.password) throw new Error('Use uma MQTT_URL mqtts:// sem credenciais.');
  const ca = readFileSync(process.env.MQTT_CA_FILE || './mqtt-ca.crt');
  const serial = new SerialPort({ path: process.env.SERIAL_PORT || 'COM4', baudRate: 115200, autoOpen: false });
  const stop = startBridge({
    terminalId, serial,
    createClient: () => connect(url.href, {
      ca, rejectUnauthorized: true,
      checkServerIdentity: (_, certificate) => checkServerIdentity(url.hostname, certificate),
      username: 'esp32', password, clientId: `esp32-${terminalId}`, protocolVersion: 5,
      clean: true, reconnectPeriod: 0, connectTimeout: 5000, queueQoSZero: false,
    }),
  });
  process.once('SIGINT', stop);
  process.once('SIGTERM', stop);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    main();
  } catch (error) {
    console.error(`[Ponte] ${error.message}`);
    process.exitCode = 1;
  }
}
