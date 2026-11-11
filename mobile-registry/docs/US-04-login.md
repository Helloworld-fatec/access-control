# US-04: Login do administrador

## O que foi feito

- **Tela de login** (`features/auth/presentation/login_screen.dart`): e-mail, senha, opção
  "Mostrar senha", botão grande com indicador de carregamento, mensagens de erro em linguagem
  simples e acesso a "Configurar servidor" (sem servidor configurado não há como entrar).
- **`POST /auth/login`** pelo cliente HTTP único. Corpo: `{ email, password }` (e-mail aparado e em
  minúsculas). Resposta esperada: `{ accessToken, user: { id, name, email, role } }`.
- **Token no armazenamento seguro** (`flutter_secure_storage`, Keystore do Android). Nunca em
  `shared_preferences`. O perfil mínimo (id, nome, e-mail, perfil) é guardado junto.
- **Somente administradores**: se `user.role` não for `ADMIN`, o app recusa **antes** de gravar
  qualquer coisa ("Acesso negado. Este aplicativo é exclusivo para administradores.").
- **Sessão restaurada na abertura**: com token e perfil válidos guardados, o app abre direto na
  área do administrador. Sem sessão, abre no login.
- **Rotas protegidas** (go_router): sem sessão, tudo leva ao login (exceto Configurações);
  com sessão, a tela de login não é acessível.

## Mensagens do login

| Situação | Mensagem |
|---|---|
| 401 | E-mail ou senha incorretos. |
| 403 ou perfil diferente de ADMIN | Acesso negado. Este aplicativo é exclusivo para administradores. |
| 404 | Não encontramos o serviço de login neste servidor. Confira o endereço e a porta em Configurações. |
| 400 | Confira o e-mail e a senha informados. |
| Sem rede / timeout / 5xx | Mensagens padrão do cliente HTTP (US-03) |
| Resposta fora do formato | O servidor respondeu algo inesperado. Tente novamente. |
| Falha no Keystore | Não foi possível guardar o acesso com segurança neste aparelho. |

## Detalhes de segurança

- A rota de login envia `skipAuth` (não manda token antigo) e `skipSessionExpired` (um 401 de
  "senha errada" não é "sessão expirada").
- O POST de login só é repetido se a requisição nem chegou ao servidor (regra do retry).
- A senha não é guardada, registrada nem alterada (espaços fazem parte dela).
- `android:allowBackup="false"`: o token não entra em backups do Android.
- Se o Keystore ficar ilegível (ex.: aparelho restaurado), o conteúdo é descartado e o usuário
  entra de novo, em vez de o app falhar a cada abertura.

## Como testar sem o backend real

O backend enviado ainda **não tem** `POST /api/auth/login`. Para testar o app agora:

```bash
cd mobile-registry
dart run tool/dev_auth_server.dart        # porta 3000 (use outra com: ... 3001)
```

| E-mail | Senha | Resultado no app |
|---|---|---|
| admin@teste.com | qualquer | Entra (ADMIN) |
| morador@teste.com | qualquer | Acesso negado (RESIDENT) |
| qualquer outro | qualquer | E-mail ou senha incorretos |

No app, configure o IP do computador (emulador: `10.0.2.2`) e a porta. Este servidor não valida
senha: é só para desenvolvimento.

## Limites desta etapa (ficam para a US-05)

- Não há botão **Sair**. Para entrar de novo com outra conta durante os testes, limpe os dados do
  app (Configurações do Android > Apps > Registro de Acesso > Armazenamento > Limpar dados).
- Um token expirado só é percebido quando uma chamada autenticada recebe 401. O evento já é
  emitido (`sessionExpiredProvider`), mas o tratamento global é da US-05.
- Ao reabrir o app, a sessão guardada é aceita sem consultar o servidor (não existe rota de
  verificação no backend).

## Arquivos

Novos: `core/storage/secure_store.dart`, `features/auth/**`, `tool/dev_auth_server.dart`.
Alterados: `main.dart`, `core/router/app_router.dart`, `core/network/token_store.dart`,
`core/network/network_providers.dart`, `features/home/presentation/home_screen.dart`,
`pubspec.yaml` (flutter_secure_storage), `AndroidManifest.xml` (allowBackup),
`android/app/build.gradle.kts` (minSdk >= 23).
