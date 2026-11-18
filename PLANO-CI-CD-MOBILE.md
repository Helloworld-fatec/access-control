# Plano de CI/CD para os aplicativos Flutter

## Objetivo

Criar workflows para `mobile-user`, `mobile-readings` e `mobile-registry`. Em PRs direcionados a `stage`, executar lint/análise, testes e build Android. Em PRs direcionados a `main`, repetir as verificações, gerar APKs e salvá-los como artefatos por 14 dias. A publicação nas lojas ficará comentada como exemplo, sem executar. Para frontend e backend, criar CI que rode somente lint; o deploy permanece automático nos serviços já usados: Cloudflare para frontend e Render para backend. A configuração para PRs direcionados a `develop` ficará comentada.

## 1. Estado atual encontrado

- Existe apenas `.github/workflows/mobile-registry-ci.yml`. Ele dispara em `push` e `pull_request` quando há alteração em `mobile-registry/**`, sem restringir a branch alvo. Executa `flutter pub get`, `flutter analyze --no-fatal-infos`, `flutter test --coverage` e `flutter build apk --debug`.
- `mobile-registry` fica na raiz em `mobile-registry/`, tem Android, testes e não tem diretório iOS.
- `mobile-readings` fica em `mobile-readings/`, tem Android, iOS e testes unitários/widget.
- O projeto Flutter de `mobile-user` fica em `mobile-user/mobileuser/`, não diretamente em `mobile-user/`. Tem Android, iOS e apenas o teste de widget inicial.
- Os três apps têm `pubspec.lock`. Os metadados desses locks pedem Flutter `3.44.0` ou superior, então a versão do Flutter no runner precisa satisfazer esse requisito. Os projetos Android usam Java 17.
- Os três projetos Android estão configurados para assinar o build `release` com a chave de debug. Isso serve para desenvolvimento, mas não serve para publicar uma versão assinada aos usuários.
- Os IDs Android de `mobile-user` e `mobile-readings` ainda são `com.example.*`; o de `mobile-registry` é `br.fatec.accesscontrol.mobile_registry`. Não há configuração de Firebase App Distribution, Play Store, App Store, Fastlane ou credenciais de publicação no repositório.
- O frontend tem `npm run lint`. O backend não tinha script de lint e usava TypeScript 7.0.2, incompatível com a faixa suportada pelo `typescript-eslint`; para habilitar ESLint sem ignorar essa incompatibilidade, o setup do backend usa TypeScript 6.0.3 e registra o script/configuração ESLint.
- O backend deve continuar com deploy automático no Render, e o frontend na Cloudflare. Este plano prevê CI de lint para esses diretórios, sem job de deploy nesses workflows.
- O repositório local só mostra `main` como branch local e não lista `stage` ou `develop` entre as branches remotas disponíveis. Confirmar/criar as branches antes de depender dos checks nelas.

## 2. Escopo de publicação nas lojas

Neste plano, o workflow móvel para PR a `main` **gera os APKs e os publica como artefatos do GitHub Actions, com retenção de 14 dias**. Não envia nada para lojas. “Publicação nas lojas” é uma etapa futura e ficará representada apenas em exemplos YAML comentados.

O projeto não tem os IDs, certificados nem credenciais necessários. Além disso, Google Play normalmente recebe um Android App Bundle (AAB) para publicação, enquanto a App Store recebe um pacote iOS (IPA); os APKs do workflow servem como artefatos de teste. Para ativar lojas, será necessário configurar assinatura Android, gerar AAB e configurar assinatura iOS em runner macOS, além de fornecer as chaves de API apropriadas. Nenhuma chave deve ser commitada.

### Impedimentos para publicação de produção

1. Criar application IDs Android definitivos para `mobile-user` e `mobile-readings` e confirmar o ID de `mobile-registry`.
2. Gerar e guardar keystores de release fora do Git; configurar secrets de assinatura do Android e alterar os Gradle files para usar a assinatura de release somente no job apropriado.
3. Definir versionamento e incremento de `versionCode`/`versionName` para os três `pubspec.yaml`.
4. Para iOS, confirmar Bundle IDs, certificados, profiles e conta Apple. Os workflows de iOS exigem runner macOS. `mobile-registry` não contém atualmente a estrutura iOS.
5. Para a Google Play, preparar AAB assinado e credencial de Service Account com acesso ao app/track. Para a App Store, preparar IPA assinado, certificado e provisioning profile, além de App Store Connect API Key (`.p8`, Key ID e Issuer ID).
6. Guardar keystores e credenciais como GitHub Secrets/Environment Secrets. Não inserir chaves privadas nos repositórios, artefatos ou logs.

## 3. Workflows a criar/ajustar

Criar cinco arquivos em `.github/workflows/`:

```text
mobile-user-ci-cd.yml
mobile-readings-ci-cd.yml
mobile-registry-ci-cd.yml
frontend-ci.yml
backend-ci.yml
```

O terceiro substitui `.github/workflows/mobile-registry-ci.yml`; remover o antigo quando o novo estiver pronto para evitar CI duplicado.

Nos três workflows Flutter, restringir o evento `pull_request` às branches alvo abaixo e filtrar caminhos do próprio app e do workflow correspondente:

```yaml
on:
  pull_request:
    branches:
      - stage
      - main
      # - develop  # habilitar quando a branch develop entrar no fluxo
```

O evento `pull_request.branches` filtra a branch de destino do PR. Não configurar `push` como substituto: o requisito é rodar nos PRs para essas branches.

Nos workflows web (`frontend-ci.yml` e `backend-ci.yml`), usar os mesmos alvos de PR (`stage` e `main`, com `develop` comentada), mas executar somente o lint. Acrescentar comentários explicativos: `# Deploy automático no Render após merge/push para a branch configurada` no workflow backend e `# Deploy automático na Cloudflare após merge/push para a branch configurada` no frontend. Esses comentários documentam a hospedagem; não adicionam passos que publiquem via Actions.

### Caminhos de cada app

| Workflow | Diretório de trabalho | Paths relevantes |
|---|---|---|
| `mobile-user-ci-cd.yml` | `mobile-user/mobileuser` | `mobile-user/mobileuser/**` e o próprio workflow |
| `mobile-readings-ci-cd.yml` | `mobile-readings` | `mobile-readings/**` e o próprio workflow |
| `mobile-registry-ci-cd.yml` | `mobile-registry` | `mobile-registry/**` e o próprio workflow |
| `frontend-ci.yml` | `frontend` | `frontend/**` e o próprio workflow |
| `backend-ci.yml` | `backend` | `backend/**` e o próprio workflow |

Incluir o arquivo do workflow em `paths` para que alterações no pipeline também validem o próprio pipeline. Não incluir diretórios de outros apps no workflow individual.

## 4. Pipeline Flutter em PR para `stage` e `main`

Cada um dos três workflows deve executar as etapas abaixo em runner Ubuntu, com Java 17 e Flutter compatível com os locks:

1. Fazer checkout do código.
2. Configurar Java 17 com `actions/setup-java`.
3. Configurar Flutter estável em versão compatível (mínimo indicado pelos locks: `3.44.0`) com cache de pub.
4. Entrar no diretório do app e rodar `flutter pub get`.
5. Rodar análise estática/lint com `flutter analyze`. Manter `--no-fatal-infos` no `mobile-registry` inicialmente para preservar a política do workflow existente; padronizar depois de revisar os avisos.
6. Rodar os testes automatizados com `flutter test --coverage`.
7. Compilar Android em modo debug com `flutter build apk --debug`, que não requer keystore de publicação.
8. Fazer o job falhar se dependências, análise, testes ou build falharem. Tornar os checks obrigatórios nas regras de proteção de `stage` e `main`.

Como checagem adicional de lint/estilo, considerar `dart format --output=none --set-exit-if-changed lib test`. Adicionar somente após formatar e revisar o código existente, para não bloquear todos os PRs por formatação preexistente.

### Cobertura de testes atual

- `mobile-readings`: há testes de cliente API, controlador e formatação de UID NFC.
- `mobile-registry`: há testes de widget, rede, configurações, navegação, autenticação, NFC e usuários.
- `mobile-user`: só foi encontrado `test/widget_test.dart`, típico de scaffold Flutter. O workflow ainda pode executar `flutter test`, mas é necessário avaliar se o teste inicial testa algo útil e adicionar testes do fluxo de login, leitura de QR e validação antes de tratar a cobertura como representativa.

## 5. Artefatos APK para PRs direcionados a `main`

1. Reutilizar os checks Flutter da seção anterior; só gerar artefato quando lint/análise, testes e build passarem.
2. Para cada app, executar `flutter build apk --debug`. O modo debug evita usar a chave de debug que hoje está indevidamente configurada como assinatura de `release` nos Gradle files.
3. Salvar `build/app/outputs/flutter-apk/app-debug.apk` com `actions/upload-artifact`, nome identificando app, SHA do commit e número do PR, e `retention-days: 14`.
4. Expor o link para baixar o artefato no resumo do workflow. O artefato serve para revisão/teste e não é uma publicação de loja.
5. Nos PRs para `stage`, executar lint/testes/build, mas não é necessário subir artefato. Nos PRs para `main`, subir o APK por 14 dias após sucesso das verificações.
6. Não adicionar gatilho de publicação Play Store/App Store ativo.

### Exemplo do passo de artefato (ativo no PR para `main`)

```yaml
- name: Salvar APK por 14 dias
  if: github.base_ref == 'main'
  uses: actions/upload-artifact@v4
  with:
    name: mobile-user-apk-${{ github.event.pull_request.number }}-${{ github.sha }}
    path: mobile-user/mobileuser/build/app/outputs/flutter-apk/app-debug.apk
    retention-days: 14
```

Cada workflow usa seu próprio diretório e nome de app.

### Exemplos de publicação futura (deixar comentados)

Os passos abaixo são apenas referência e devem ficar comentados nos workflows até que IDs, assinatura, contas e chaves estejam configurados. Os comandos pressupõem Fastlane configurado para cada app; não serão executados pelo CI atual.

```yaml
# Publicação futura Android na Google Play — requer AAB assinado e Service Account JSON.
# - name: Publicar na Google Play (desativado)
#   if: false
#   run: bundle exec fastlane android deploy
#   env:
#     PLAY_SERVICE_ACCOUNT_JSON: ${{ secrets.PLAY_SERVICE_ACCOUNT_JSON }}
#     ANDROID_KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
#     ANDROID_KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
#     ANDROID_KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
#     ANDROID_KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}

# Publicação futura iOS na App Store — requer IPA assinado, certificado/profile e chave App Store Connect.
# - name: Publicar na App Store (desativado; exige runner macOS)
#   if: false
#   run: bundle exec fastlane ios deploy
#   env:
#     APP_STORE_CONNECT_API_KEY_BASE64: ${{ secrets.APP_STORE_CONNECT_API_KEY_BASE64 }} # arquivo .p8
#     APP_STORE_CONNECT_KEY_ID: ${{ secrets.APP_STORE_CONNECT_KEY_ID }}
#     APP_STORE_CONNECT_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
#     IOS_CERTIFICATE_BASE64: ${{ secrets.IOS_CERTIFICATE_BASE64 }}
#     IOS_CERTIFICATE_PASSWORD: ${{ secrets.IOS_CERTIFICATE_PASSWORD }}
#     IOS_PROVISIONING_PROFILE_BASE64: ${{ secrets.IOS_PROVISIONING_PROFILE_BASE64 }}
```

Antes de descomentar qualquer publicação, trocar `if: false` por condições de branch/environment apropriadas, adicionar os arquivos Fastlane, validar assinatura e configurar aprovação manual. Nunca salvar os valores das chaves no YAML.

## 6. Workflows lint-only para frontend e backend

### Frontend (`frontend-ci.yml`)

1. Disparar em PR para `stage` e `main`; manter `develop` comentada.
2. Usar Node LTS compatível com o lockfile, `npm ci` e `npm run lint` no diretório `frontend`.
3. Não rodar testes, build ou deploy neste workflow, conforme o escopo pedido.
4. Registrar em comentário que o deploy de frontend é automático pela Cloudflare, conforme a branch configurada no projeto Cloudflare.

### Backend (`backend-ci.yml`)

1. Disparar em PR para `stage` e `main`; manter `develop` comentada.
2. Manter ESLint e sua configuração no backend, além do script `lint` no `backend/package.json`; a versão TypeScript 6.0.3 fica alinhada à faixa de peer dependency suportada pelo `typescript-eslint` utilizado.
3. Rodar instalação com `npm ci` e somente `npm run lint` no diretório `backend`.
4. Não executar build, testes, migrações ou deploy neste workflow.
5. Registrar em comentário que o deploy do backend é automático pelo Render, conforme a branch configurada no serviço.

Os workflows da Cloudflare e do Render devem ficar responsáveis pelo deploy após os eventos já configurados nos respectivos serviços; este CI apenas fornece o check de lint para o PR.

## 7. Particularidades por app

### `mobile-user`

- Usar `mobile-user/mobileuser` como diretório de execução em todos os comandos; o README em `mobile-user/` é atualmente o README padrão do Flutter, então atualizá-lo com as instruções do app e do workflow.
- Compilar APK debug em Ubuntu. iOS só em uma etapa futura com runner macOS, Bundle ID definitivo e assinatura Apple configurada.
- Adicionar testes além do widget de scaffold para dar cobertura às funções principais do app.

### `mobile-readings`

- Executar os testes atuais e o build Android debug.
- O app tem pastas Android e iOS, mas usa application ID e Bundle ID `com.example.mobilereadings`/`com.example.mobileuser`. Confirmar IDs antes de distribuir.
- A etapa iOS requer runner macOS e assinatura Apple; não misturar certificados no job de lint/teste Android.

### `mobile-registry`

- Migrar o workflow existente para o nome novo e limitar os PRs a `stage` e `main` (com `develop` comentada).
- Preservar temporariamente `flutter analyze --no-fatal-infos`, `flutter test --coverage` e build APK debug.
- Há apenas projeto Android no diretório; definir separadamente se será criado iOS.
- Corrigir a assinatura debug no build `release` antes de qualquer distribuição real.

## 8. Segurança e configuração dos workflows

1. Definir `permissions` mínimos por job. Para apenas compilar e subir artifact, usar leitura do conteúdo e escrita de artifacts quando necessário; não conceder escrita ampla no repositório.
2. Não armazenar keystore, certificados, tokens Firebase ou credenciais Play Store nos arquivos versionados. Guardar em GitHub Actions Secrets e Environment Secrets.
3. Não disponibilizar secrets em PRs de forks. O job de CI sem secrets deve continuar rodando para esses PRs.
4. Se houver publicação automática para testadores, usar environment com aprovação e limitar o job à branch/evento autorizado.
5. Adicionar `concurrency` por workflow/PR para cancelar builds antigos quando novos commits forem enviados ao mesmo PR.
6. Usar versões fixadas das actions e manter as actions atualizadas conforme política do repositório.

## 9. Configuração do GitHub após criar os workflows

1. Criar ou confirmar as branches `stage` e `develop` no remoto.
2. Em **Settings → Branches / Rulesets**, exigir os checks dos três apps Flutter e os checks de lint de frontend/backend antes de merge em `stage` e `main`.
3. Para `main`, exigir também aprovação de revisão. Se houver publicação de testadores, configurar environment e reviewers.
4. Não ativar `develop` ainda: a linha ficará comentada nos cinco workflows e será habilitada numa alteração futura quando a branch e o fluxo forem acordados.
5. Abrir PRs de teste para `stage` e para `main`, confirmar execução dos workflows e download dos APK artifacts.
6. Depois de escolher o destino real de distribuição e configurar IDs/assinatura/secrets, habilitar o passo de deploy específico e testar primeiro num grupo interno.

## 10. Critérios de conclusão

- PR direcionado a `stage` executa análise/lint, testes e build Android dos apps Flutter alterados; frontend e backend executam somente lint.
- PR direcionado a `main` executa os mesmos checks Flutter e guarda o APK de cada app como artifact por 14 dias; frontend e backend executam somente lint.
- Nenhum passo ativo publica na Play Store ou App Store. Os exemplos de publicação ficam comentados e listam as credenciais necessárias.
- Comentários deixam explícito que os deploys do Render (backend) e Cloudflare (frontend) são automáticos e não são executados pelos workflows de CI.
- A alteração ao workflow de `mobile-registry` não mantém dois pipelines duplicados.
- Nenhum PR para `develop` dispara os workflows enquanto a branch permanecer comentada.
- O CI usa os diretórios corretos, respeita os locks Flutter, roda em Java 17 e não depende de assinatura privada para os checks comuns.
- Arquivos e secrets de assinatura não são commitados; artefatos sem assinatura de release não são apresentados como distribuição de produção.
