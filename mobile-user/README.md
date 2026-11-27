# mobile-user

App Flutter do **usuário final** (condômino ou visitante) do access-control. É deliberadamente simples e tem três funções: autenticar o usuário, mostrar as autorizações que ele possui e ler o QR Code exibido no terminal de acesso. O app não valida o QR nem decide o acesso: repassa o token ao backend, que responde se o acesso foi liberado ou negado.

Responsável: Bruno. O projeto Flutter está em [`mobileuser/`](./mobileuser).

## Funcionalidades

| Tela | O que faz | Rota do backend |
|---|---|---|
| Login | Pede a URL do backend, o e-mail e a senha. O token JWT fica em armazenamento seguro (`flutter_secure_storage`) e a sessão é restaurada ao abrir o app | `POST /api/login` |
| Início | Navegação entre as funções | |
| Minhas autorizações | Lista as autorizações do usuário logado | `GET /api/authorizations/me` |
| Leitor de QR | Lê o QR do terminal com a câmera (`mobile_scanner`) e envia o token | `POST /api/access/qr/consume` |

Ao restaurar a sessão salva, se o backend responder `401`, o app encerra a sessão e volta ao login.

## Como rodar

Pré-requisitos: Flutter, e o backend rodando (veja [`docs/como-executar.md`](../docs/como-executar.md)). O celular e o computador do backend precisam estar na mesma rede.

```bash
cd mobile-user/mobileuser
flutter pub get
flutter run
```

Na tela de login, informe a URL do backend, por exemplo `http://192.168.0.10:3000`. No emulador Android, o computador é `10.0.2.2`.

Testes: `flutter test`.

## Estrutura

```
mobileuser/lib/
├── app/         aplicativo e rotas
├── core/
│   ├── api/       cliente HTTP do backend
│   ├── session/   sessão e armazenamento do token
│   ├── theme/     paleta de cores e tema
│   └── widgets/   componentes compartilhados
├── data/        modelo de autorização
└── features/
    ├── auth/            login
    ├── home/            início
    ├── authorizations/  lista de autorizações
    └── qr/              leitor de QR
```

O visual segue a paleta nos tons da Fatec, a mesma do painel web e do app de cadastro.

## Limitações atuais

- O app **não envia a localização** do celular ao ler o QR, então a validação de proximidade do requisito RF13 ainda não existe (veja [`docs/matriz-requisitos.md`](../docs/matriz-requisitos.md)).
- O backend só aceita o QR emitido por `POST /api/terminals/me/qr` (token de 43 caracteres). Veja [`docs/api.md`](../docs/api.md).
