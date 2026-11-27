# mobile-user

Aplicativo Flutter para usuários do sistema de controle de acesso.

## Executar localmente

```bash
cd mobile-user/mobileuser
flutter pub get
flutter run
```

## Análise, testes e build Android

```bash
flutter analyze
flutter test --coverage
flutter build apk --debug
```

O workflow `.github/workflows/mobile-user-ci-cd.yml` roda esses passos em PRs para `stage` e `main`. Em PR para `main`, o APK de debug é disponibilizado como artefato do GitHub Actions por 14 dias. Os passos de publicação nas lojas permanecem comentados e exigem assinatura e credenciais próprias.
