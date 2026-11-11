# US-05: Expiração de sessão e logout

## O que foi feito

- **Botão Sair** na tela inicial (botão grande) e ícone na barra superior. Pede confirmação
  ("Sair do aplicativo?"), para evitar saída por toque acidental.
- **Limpeza segura**: ao sair, token e perfil são apagados do armazenamento seguro (Keystore) e só
  depois o app volta ao login. Se o aparelho falhar ao apagar um dos dois, o outro é apagado mesmo
  assim e o usuário sai da área logada de qualquer forma.
- **Tratamento global de 401**: qualquer resposta 401 a uma chamada autenticada, em qualquer tela,
  encerra a sessão, limpa o armazenamento e leva ao login com o aviso
  "Sua sessão terminou. Entre novamente."
- **Sem volta**: ao perder a sessão o roteador usa `go('/login')`, que descarta a pilha de telas.
  Nenhuma tela protegida fica "por baixo" para o botão voltar revelar (inclusive quando a sessão
  expira com as Configurações abertas).

## Como funciona

```
Dio recebe 401 (chamada autenticada)
  -> ErrorInterceptor chama onUnauthorized(tokenEnviado)
  -> sessionExpiredProvider.notify(tokenEnviado)
  -> AuthNotifier (escuta o evento) confere se o token ainda é o atual
  -> apaga token + perfil -> estado "deslogado, motivo: expirada"
  -> roteador faz go('/login') -> tela de login mostra o aviso
```

Quem decide é o `AuthNotifier` (`features/auth/application/auth_providers.dart`): é o ponto único
que encerra a sessão, tanto pelo botão Sair (`signOut()`) quanto pelo 401.

## Decisões de segurança

- **401 atrasado não derruba sessão nova.** O evento leva o token que a requisição enviou. Se o
  usuário saiu e entrou de novo enquanto uma chamada antiga ainda estava no ar, o 401 dessa chamada
  (token antigo) é ignorado.
- **Várias chamadas recusadas ao mesmo tempo** encerram a sessão uma única vez.
- **Apaga primeiro, "sai" depois.** Assim, um login feito logo em seguida nunca é apagado por uma
  limpeza atrasada.
- **Login e teste de conexão não contam como sessão expirada.** Um 401 em `POST /auth/login` é
  "senha errada" (US-04) e um 401 em `GET /health` não diz nada sobre o token.
- **Falha na limpeza ao abrir o app não impede o app de abrir** (`restore()` ignora o erro e segue
  sem sessão).
- Não há chamada de logout ao servidor: o backend não tem essa rota e o token é do tipo
  stateless. A saída é local. Se o backend ganhar revogação de token, basta chamá-la em
  `AuthNotifier.signOut()`.

## Mensagens

| Situação | Onde aparece | Texto |
|---|---|---|
| Sessão expirada (401) | Aviso azul no login | Sua sessão terminou. Entre novamente. |
| Saiu pelo botão | (nenhum aviso) | |
| Confirmação | Diálogo | Sair do aplicativo? / Você precisará entrar novamente com seu e-mail e senha. |

## Como verificar

**Pelos testes automatizados (já agora).** `auth_session_test.dart` e `logout_flow_test.dart`
simulam o 401 e conferem: sessão encerrada, armazenamento vazio, volta ao login com o aviso e
nenhuma tela protegida acessível depois (inclusive com as Configurações abertas).

**À mão, no app.**

- *Sair*: funciona agora. Entre como `admin@teste.com` e toque em **Sair** (botão grande na tela
  inicial, ou o ícone na barra superior).
- *Sessão expirada*: **ainda não dá para ver no app**, porque hoje nenhuma tela faz uma chamada
  autenticada (a lista de usuários chega na US-06). Quando existir, o roteiro é:
  1. `dart run tool/dev_auth_server.dart` e entre no app como `admin@teste.com`;
  2. abra `http://<ip>:3000/api/dev/expire-tokens` no navegador (invalida os tokens emitidos);
  3. no app, faça qualquer ação que busque dados: o 401 leva ao login com o aviso.

## Arquivos

Novos: `features/auth/presentation/logout_action.dart`, testes `auth_session_test.dart` e
`logout_flow_test.dart`.

Alterados: `core/network/interceptors/error_interceptor.dart` (leva o token), `core/network/api_client.dart`,
`core/network/network_providers.dart`, `core/widgets/status_message.dart` (variante informativa),
`core/router/app_router.dart`, `features/auth/application/auth_providers.dart`,
`features/auth/data/session_storage.dart`, `features/auth/presentation/login_screen.dart`,
`features/home/presentation/home_screen.dart`, `features/settings/data/connection_repository.dart`, `tool/dev_auth_server.dart` (rota `/api/dev/expire-tokens`);
testes `api_client_test.dart`, `network_providers_test.dart`, `session_storage_test.dart` e os helpers
`memory_secure_store.dart` e `test_app.dart`.

## Fica para depois

- Nenhuma tela faz hoje chamada autenticada; o aviso de sessão expirada só aparece no uso real a partir da US-06.
- Telas futuras (lista de usuários etc.) devem incluir `LogoutAppBarAction()` na barra superior.
- Verificação do token ao abrir o app (hoje a sessão guardada é aceita; se estiver expirada, o
  primeiro 401 a encerra).
