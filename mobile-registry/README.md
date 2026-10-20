# mobile-registry

App Flutter do administrador (cadastro de usuários, tags NFC e rosto) do
**Sistema Integrado de Controle de Acesso**. O app só coleta e envia dados;
o backend valida e decide (RP05).

## Escopo desta etapa

| US | Entrega |
|---|---|
| US-01 | Estrutura em camadas (feature-first + `core`), Riverpod, tema, navegação (go_router) e tratamento global de erros |
| US-02 | Tela de configuração (IP/porta, tamanho da foto, capturas do rosto), persistida e aplicada na hora; permissões Android |
| US-03 | Cliente HTTP único (Dio) com interceptadores, retry, timeouts e erros padronizados |
| US-21 | Design system acessível (paleta obrigatória, botões grandes, alto contraste, `Semantics`) |
| US-22 | Testes unitários e de widget + workflow de CI |

Login (US-04) e expiração/logout (US-05) ficam para a próxima etapa. Já existem
os ganchos: `TokenStore` (trocar por `flutter_secure_storage`) e `sessionExpiredProvider` (evento de 401).

## Como criar o projeto Android

Este pacote traz só o código-fonte. Gere a casca nativa e sobreponha os arquivos:

```bash
# na raiz do repositório access-control
flutter create --org br.fatec.accesscontrol --project-name mobile_registry --platforms android mobile-registry
# extraia este pacote por cima (substitui pubspec.yaml, lib/, test/, analysis_options.yaml
# e android/app/src/main/AndroidManifest.xml)
cd mobile-registry
flutter pub get
flutter analyze
flutter test
flutter run            # aparelho Android real ou emulador
```

> `flutter create` gera um `test/widget_test.dart` de exemplo; o deste pacote o substitui.

## Configurar o backend

Na tela inicial, **Configurar servidor**: informe o IP do notebook que roda o
backend (ex.: `192.168.0.10`) e a porta (`3000`). Celular e notebook precisam
estar na mesma rede. No emulador Android use `10.0.2.2`.
O botão **Salvar e testar conexão** chama `GET /api/health`.

## Arquitetura

```
lib/
  core/
    config/    AppSettings, validações, repositório (shared_preferences), providers
    network/   createApiClient (Dio), interceptadores, ApiException, TokenStore
    theme/     AppColors, AppTheme (design system)
    widgets/   AppPrimaryButton, AppSecondaryButton, StatusMessage, InfoCard
    router/    rotas (go_router)
    error/     tratamento global de erros
  features/
    home/      presentation
    settings/  data · application · presentation
```

Regra de dependência: `presentation → application → data → core`.
Cada nova feature (usuários, NFC, rosto) segue a mesma divisão.

### Cliente HTTP (US-03)

Ordem dos interceptadores: URL base (relida a cada chamada) → token → retry → erro.

- Retry: até 3 novas tentativas, espera de 0,5 s / 1 s / 2 s.
  `GET/PUT/DELETE` repetem em timeout, queda de conexão e 502/503/504.
  `POST/PATCH` só repetem se a requisição nem chegou ao servidor, para nunca duplicar um cadastro.
- Erros viram `ApiException` (`kind` + mensagem simples). O formato do backend
  `{ error: { code, message, details } }` é interpretado; erros 500 nunca mostram texto técnico.
- `ApiException.from(e)` nos repositórios; `userMessageFor(e)` nas telas.

### Paleta

| Uso | Cor |
|---|---|
| Principal | `#31566A` |
| Destaques / erros | `#B51F2E` |
| Fundo | `#F7F7F4` |
| Apoio / cards | `#E5EBEE` |

Os contrastes (mínimo 4,5:1, WCAG AA) são verificados em `test/core/theme/contrast_test.dart`.

## Testes e CI

```bash
flutter analyze
flutter test --coverage
```

O workflow `.github/workflows/mobile-registry-ci.yml` roda análise, testes e build do APK a cada push/PR (RNF08/RNF10).
