# Como executar o projeto

Guia para rodar cada serviço do access-control em ambiente de desenvolvimento. O ambiente completo com **Docker Compose** (backend, banco, broker MQTT e frontend), previsto para a entrega final, **ainda não existe**: hoje só há um Compose com o PostgreSQL de teste. Até lá, cada serviço sobe separadamente, na ordem abaixo.

Os comandos do backend foram testados em 15/11/2026 (instalação, geração do Prisma, subida do servidor e `npm test`). Os dos demais serviços vêm do README de cada um, e cada responsável deve confirmar os seus.

## Visão geral

| Ordem | Serviço | Responsável | Para que serve | Onde está o detalhe |
|---|---|---|---|---|
| 1 | Banco PostgreSQL | | Guarda usuários, autorizações e histórico | abaixo |
| 2 | `backend` | Bruno e Pedro | API e decisão de acesso | [`backend/README.md`](../backend/README.md) |
| 3 | `frontend` | Pedro | Painel web do administrador | [`frontend/README.md`](../frontend/README.md) |
| 4 | `mobile-registry` | Ryan | App de cadastro (administrador) | [`mobile-registry/README.md`](../mobile-registry/README.md) |
| 5 | `mobile-readings` | Nicolas | App do terminal (QR e NFC) | [`mobile-readings/README.md`](../mobile-readings/README.md) |
| 6 | `mobile-user` | Bruno | App do usuário (lê o QR) | [`mobile-user/README.md`](../mobile-user/README.md) |
| 7 | `device-esp32` | Bruna | Terminal físico | [`device-esp32/hardware/README.md`](../device-esp32/hardware/README.md) |

Os serviços falam com o backend por HTTP e REST. A comunicação por MQTT entre o backend e o ESP32 ainda não está integrada (veja [`contrato-mqtt.md`](./contrato-mqtt.md)).

## Pré-requisitos

- Git, Node.js 24 e Docker (para o banco).
- Flutter, para os três aplicativos.
- Arduino IDE com o pacote **esp32 by Espressif Systems**, ou uma conta no Wokwi, para o terminal.

## 1. Banco de dados

Na raiz do repositório:

```bash
docker compose -f docker-compose.test.yml up -d
```

Cria o PostgreSQL na porta `5433`, com usuário `postgres`, senha `changeme` e banco `access_control_test`. Se preferir outro PostgreSQL, use o seu e ajuste o `DATABASE_URL`.

## 2. Backend

```bash
cd backend
cp .env.example .env
```

No `.env`, defina:

```
DATABASE_URL="postgresql://postgres:changeme@localhost:5433/access_control_test?schema=public"
JWT_SECRET="uma-chave-com-pelo-menos-32-caracteres"
PORT=3000
```

```bash
npm install
npx prisma generate
npx prisma migrate deploy
npx tsx src/server.ts
```

Confira em `http://localhost:3000/api/health`. Não há seed: crie o primeiro administrador conforme o [`backend/README.md`](../backend/README.md). As rotas estão em [`docs/api.md`](./api.md).

> O `package.json` do backend ainda não tem os scripts `dev`, `build` e `start`, por isso o servidor sobe com `npx tsx`.

## 3. Frontend (painel web)

```bash
cd frontend
cp .env.example .env     # ajuste BACKEND_URL se o backend não estiver em localhost:3000
npm install
npm run dev              # http://localhost:5173
```

Só administradores entram. Para ver o painel sem backend, com dados fictícios:

```bash
npm run dev:mock         # entre com admin@teste.com e qualquer senha
```

Qualidade: `npm run check` roda tipos, ESLint e testes.

## 4. Aplicativos Flutter

Em todos, o celular e o computador do backend precisam estar na **mesma rede**. No emulador Android, o endereço do computador é `10.0.2.2`.

### mobile-registry (administrador)

```bash
cd mobile-registry
flutter pub get
flutter run
```

Na tela inicial, **Configurar servidor**: informe o IP do computador e a porta (`3000`) e use **Salvar e testar conexão**, que chama `GET /api/health`.

### mobile-readings (terminal)

```bash
cd mobile-readings
flutter pub get
flutter run
```

Na tela de configurações, informe o backend, o broker MQTT, o `terminalId` e a `apiKey` do terminal. A chave é devolvida uma única vez ao criar o terminal (`POST /api/terminals`). Há um modo de simulação para testar sem hardware. Testes: `flutter analyze` e `flutter test`.

### mobile-user (usuário)

```bash
cd mobile-user/mobileuser
flutter pub get
flutter run
```

Na tela de login, informe a **URL do backend** (por exemplo `http://192.168.0.10:3000`), o e-mail e a senha de um usuário cadastrado.

## 5. Terminal físico (ESP32)

O passo a passo completo, com a lista de componentes, a pinagem e os comandos do monitor serial, está em [`device-esp32/hardware/README.md`](../device-esp32/hardware/README.md). Em resumo:

- **Simulação:** abra um projeto ESP32 no Wokwi e copie `sketch.ino`, `diagram.json` e `libraries.txt` de `device-esp32/hardware/simulacao/wokwi/`.
- **Montagem física:** na Arduino IDE, selecione a placa **ESP32 Dev Module**, instale as bibliotecas Adafruit GFX, Adafruit SSD1306, ESP32Servo e MFRC522, envie `firmware/controle_acesso/controle_acesso.ino` e abra o monitor serial em 115200 baud.

Hoje a autorização no terminal físico é simulada pelo monitor serial (comandos `L` para liberar e `N` para negar), sem backend.

## Problemas comuns

| Sintoma | Causa provável |
|---|---|
| O backend encerra ao subir e lista "Variáveis de ambiente inválidas" | `DATABASE_URL` ausente ou `JWT_SECRET` com menos de 32 caracteres |
| `P1001: Can't reach database server` | O PostgreSQL não está rodando ou a porta do `DATABASE_URL` está errada |
| `Porta 3000 já está em uso` | Outro processo usa a porta: feche-o ou mude `PORT` no `.env` |
| O app no celular não conecta | Celular e computador em redes diferentes, ou firewall bloqueando a porta 3000 |
| `npm run dev` não encontrado no backend | O script não existe: use `npx tsx src/server.ts` |
