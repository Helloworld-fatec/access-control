# 🔐 access-control

**Sistema Integrado de Controle de Acesso** com QR Code, tag NFC e IoT.

![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)
![React](https://img.shields.io/badge/React-20232A?logo=react&logoColor=61DAFB)
![Node.js](https://img.shields.io/badge/Node.js-339933?logo=nodedotjs&logoColor=white)
![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?logo=typescript&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?logo=postgresql&logoColor=white)
![MQTT](https://img.shields.io/badge/MQTT-660066?logo=mqtt&logoColor=white)
![ESP32](https://img.shields.io/badge/ESP32-E7352C?logo=espressif&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white)

> Projeto acadêmico desenvolvido na **FATEC Jacareí** — ABP 2026-2 | 4º DSM
> Desafio de Inovação em IoT | Focal Point: Prof. Leandro Toss Hoffmann

---

## 📌 Tema do Semestre

**Sistema Integrado de Controle de Acesso**

Edifícios corporativos, instituições de ensino, condomínios e instalações públicas precisam controlar e registrar o acesso de pessoas. Mecanismos baseados em cartões, crachás ou identificação manual têm limitações de segurança, rastreabilidade e experiência do usuário.

---

## 📖 Sobre o Projeto

O **access-control** é um sistema de controle de acesso de baixo custo para edifícios. A liberação de uma catraca ou fechadura é decidida a partir de credenciais lidas por **QR Code**, **tag NFC** ou **reconhecimento facial** (extra), com validação centralizada em um backend e registro de toda tentativa de acesso.

O princípio central da arquitetura: **apps e dispositivo nunca decidem o acesso.** Os clientes coletam a credencial, o ESP32 executa o comando e o backend valida, registra e ordena a abertura.

---

## ✨ Funcionalidades

- 📱 **QR Code rotativo:** gerado no backend e renovado a cada 10 segundos no terminal de acesso
- 📍 **Validação por proximidade:** o app envia a geolocalização junto com a leitura do QR
- 📡 **Leitura de tag NFC** por leitor ligado ao ESP32, no terminal de acesso
- 🤳 **Reconhecimento facial** como credencial adicional
- 🚪 **Abertura física:** ESP32 com sensor de presença, trava eletrônica e buzzer
- 🧾 **Histórico completo** de tentativas de acesso, liberadas ou negadas
- 🗓️ **Autorizações** por pessoa, local, período, horário e número de usos
- 👥 **Perfis:** administrador, condômino e visitante
- 📊 **Painel web** com cadastros, autorizações, histórico e dashboard

---

## 🏗️ Arquitetura

```mermaid
flowchart LR
  subgraph Clientes
    RD["mobile-readings<br/>Flutter<br/>exibe QR e resultado"]
    RG["mobile-registry<br/>Flutter"]
    US["mobile-user<br/>Flutter"]
    FE["frontend<br/>React"]
  end
  subgraph Servidor["Notebook / Docker Compose (LAN)"]
    BE["backend<br/>Node.js + Express + TypeScript"]
    DB[("PostgreSQL")]
    PH[("Volume /photos")]
    MQ{{"Mosquitto (MQTT)"}}
  end
  ESP["device-esp32<br/>ESP32 + leitor NFC + HC-SR04<br/>+ trava + buzzer"]

  RD & RG & US & FE -- "HTTP / REST" --> BE
  BE --> DB
  BE --> PH
  BE <-- "MQTT" --> MQ
  MQ <-- "MQTT" --> ESP
  MQ -- "presence, result" --> RD
```

### Fluxo de acesso por QR Code

```mermaid
sequenceDiagram
  participant T as mobile-readings (terminal)
  participant U as mobile-user
  participant B as backend
  participant E as device-esp32

  T->>B: GET /terminals/{id}/qr (a cada 10 s)
  B-->>T: token assinado
  T->>T: exibe o QR Code
  U->>T: lê o QR Code
  U->>B: POST /access/qr (token + localização)
  B->>B: valida credencial, autorização e proximidade
  B->>E: MQTT command (open / deny)
  E-->>B: MQTT ack
  B-->>U: acesso liberado ou negado
```

### Serviços

| Serviço | Tecnologia | Papel |
|---|---|---|
| [`mobile-readings`](./mobile-readings) | Flutter | Tela do terminal de acesso: exibe o QR rotativo e o resultado; reconhecimento facial (extra) |
| [`mobile-registry`](./mobile-registry) | Flutter | App do administrador: usuários, tags NFC, foto e dado facial |
| [`mobile-user`](./mobile-user) | Flutter | App do usuário: login, leitura do QR com GPS e lista de autorizações |
| [`backend`](./backend) | Node.js, Express, TypeScript, Prisma | Regras de negócio, decisão de acesso e ponte MQTT |
| [`frontend`](./frontend) | React | Painel web de administração e dashboard |
| [`device-esp32`](./device-esp32) | ESP32 (Arduino), leitor NFC, HC-SR04, trava, buzzer | Leitura de tags NFC, presença, atuação e sinalização |

---

## 🛠️ Tecnologias

| Camada | Tecnologia |
|---|---|
| Aplicativos móveis | Flutter |
| Frontend | React + TypeScript |
| Backend | Node.js + Express + TypeScript |
| Validação de dados | Zod |
| Banco de dados | PostgreSQL |
| ORM | Prisma |
| Segurança de senhas | bcrypt |
| Upload de fotos | Multer |
| Mensageria | MQTT (Mosquitto) |
| Firmware | ESP32 (Arduino, C/C++) |
| Leitor NFC | Módulo de 13,56 MHz ligado ao ESP32 |
| Containerização | Docker + Docker Compose |

---

## 👥 Equipe

| Nome | Papel | Responsabilidade |
|---|---|---|
| Bruno Berval | Product Owner (PO) | mobile-user, backend e integração |
| Suelen Castro | Scrum Master (SM) | Documentação, Scrum e integração |
| Pedro Enrique | Dev Team | backend e frontend |
| Nicolas Kauê | Dev Team | mobile-readings |
| Ryan Tinel | Dev Team | mobile-registry |
| Bruna Rodrigues | Dev Team | device-esp32 |

---

## 🔄 Metodologia Ágil (Scrum)

O projeto é desenvolvido em **3 sprints**, com papéis definidos, backlog priorizado, entregas incrementais, revisão e retrospectiva.

### Cronograma

| Marco | Data | Foco principal |
|---|---|---|
| Kick-off | 30/09/2026 | Início do projeto |
| Sprint Review 1 | 21/10/2026, 19h30 | Base do projeto: repositório, documentação e início do código de cada serviço |
| Sprint Review 2 | 11/11/2026, 19h30 | Fluxos de acesso por QR Code e NFC integrados entre apps, backend e ESP32 |
| Sprint Review 3 | 25/11/2026, 19h30 | CI/CD, testes automatizados, refinamento e demonstração final |
| Apresentação final | A definir | Todos os serviços funcionando, executando localmente com Docker |

### 🏃 Sprints

| Sprint | Documentação |
|---|---|
| Sprint 1 | [scrum/sprints/sprint-1.md](./scrum/sprints/sprint-1.md) |
| Sprint 2 | Em breve |
| Sprint 3 | Em breve |

---

## ✅ Requisitos Funcionais

| ID | Descrição |
|---|---|
| RF01 | Cadastro de usuários nos perfis administrador, condômino e visitante |
| RF02 | Cadastro de locais de acesso (edifício, portaria, porta e catraca) |
| RF03 | Criação de autorização de acesso |
| RF04 | Consulta de autorizações com filtros |
| RF05 | Cancelamento de autorização |
| RF06 | Consulta do histórico de acessos |
| RF07 | Autenticação do usuário no aplicativo |
| RF08 | Consulta das autorizações pelo usuário |
| RF09 | Leitura do QR Code pelo aplicativo |
| RF10 | Leitura de tag NFC no terminal de acesso |
| RF11 | Terminal de acesso com processamento, rede, tela, NFC, sinalização, GPS e mecanismo de abertura |
| RF12 | Geração do QR Code no backend, renovado a cada 10 segundos |
| RF13 | Validação de acesso via QR Code, incluindo proximidade geográfica |
| RF14 | Validação de acesso via tag NFC |
| RF15 | Liberação do acesso por mecanismo físico ou simulado |
| RF16 | Negação do acesso com indicação visual ou sonora |
| RF17 | Registro de toda tentativa de acesso |

---

## 🔧 Requisitos Não Funcionais

| ID | Descrição |
|---|---|
| RNF01 | Arquitetura com dispositivo IoT, backend Node.js/TypeScript, API REST e app móvel |
| RNF02 | Segurança: autenticação, proteção de dados sensíveis e comunicação segura |
| RNF03 | Confiabilidade, com retry ou armazenamento local diante de falhas de conexão |
| RNF04 | Usabilidade, com interface simples e acessível, inclusive ao público idoso |
| RNF05 | Manutenibilidade: organização modular e separação de responsabilidades |
| RNF06 | Persistência de dados em banco de dados em nuvem |
| RNF07 | Eficiência energética do dispositivo IoT |
| RNF08 | Integração contínua: build, testes e verificação de qualidade a cada commit |
| RNF09 | Entrega contínua para homologação ou produção |
| RNF10 | Testes automatizados executados no pipeline |
| RNF11 | Controle de versão com Git, branches organizadas e commits descritivos |
| RNF12 | Feedback claro de falhas e sucessos de build, testes e deploy |

---

## 🚀 Como Rodar

> A entrega final executa **localmente com Docker Compose** (backend, banco, broker MQTT e frontend). As instruções completas serão publicadas quando o ambiente estiver pronto. Por enquanto, o backend pode ser executado isoladamente para desenvolvimento.

### Backend (ambiente de desenvolvimento)

**Pré-requisitos:** Node.js (versão LTS) e um PostgreSQL acessível.

```bash
git clone https://github.com/Helloworld-fatec/access-control.git
cd access-control/backend

cp .env.example .env
```

Edite o `.env`:

| Variável | Obrigatória | Padrão | Descrição |
|---|---|---|---|
| `DATABASE_URL` | Sim | — | Conexão com o PostgreSQL, por exemplo `postgresql://USUARIO:SENHA@localhost:5432/NOME_DO_BANCO?schema=public` |
| `PORT` | Não | `3000` | Porta da API |
| `PHOTOS_DIR` | Não | `photos` | Pasta onde as fotos reduzidas são gravadas (criada automaticamente) |
| `MAX_PHOTO_BYTES` | Não | `102400` | Tamanho máximo da foto enviada, em bytes (100 KB) |
| `BCRYPT_ROUNDS` | Não | `10` | Custo do hash de senha |

```bash
npm install
npx prisma generate
npx prisma migrate deploy
npm run dev
```

A API sobe em `http://localhost:3000`. Para conferir:

```bash
curl http://localhost:3000/api/health
```

Para execução em produção:

```bash
npm run build
npm start
```

#### Endpoints disponíveis

Todas as rotas ficam sob o prefixo `/api`.

| Recurso | Rota base |
|---|---|
| Saúde da API | `/api/health` |
| Usuários | `/api/users` |
| Locais de acesso | `/api/locations` |
| Terminais | `/api/terminals` |
| Autorizações | `/api/authorizations` |
| Histórico de acessos | `/api/access-logs` |

> A autenticação e a decisão de acesso por QR Code e NFC ainda estão em desenvolvimento.

---

## 📚 Documentação

| Recurso | Link |
|---|---|
| Desafio do semestre | [docs/Desafio 4DSM - 2026-2.pdf](./docs/Desafio%204DSM%20-%202026-2.pdf) |
| Arquitetura | [docs/arquitetura.md](./docs/arquitetura.md) |
| Visão geral do projeto | [docs/access-control-visao-geral.docx](./docs/access-control-visao-geral.docx) |
| Product Backlog | [scrum/BACKLOG.md](./scrum/BACKLOG.md) |
| Sprint 1 | [scrum/sprints/sprint-1.md](./scrum/sprints/sprint-1.md) |

---

## 📝 Observações de Segurança

* Nunca versione arquivos `.env` reais; o `.env.example` deve conter apenas placeholders.
* Dados biométricos (embedding e foto) são dados pessoais sensíveis e exigem consentimento registrado.
* O QR Code é um token assinado, de curta duração e uso único, validado somente no backend.
* A decisão de acesso é sempre do backend, nunca dos aplicativos ou do dispositivo.

---

<div align="center">

ABP 2026-2 · 4º DSM · FATEC Jacareí
Desafio de Inovação em IoT
Focal Point: Prof. Leandro Toss Hoffmann

</div>
