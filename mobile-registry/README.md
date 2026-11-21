# Mobile Registry

Aplicativo Android para administradores do Sistema Integrado de Controle de Acesso. O login abre a lista paginada. No formulário é possível criar, editar e excluir usuários, cadastrar uma foto com consentimento e vincular um código NFC gerado automaticamente.

## Rodar com o backend

Requer Flutter 3.47 com Dart 3.13 ou superior na série 3.x e Android 7.0 (API 24) ou superior.

Na tela de login, preencha **Endereço do servidor** e toque em **Testar conexão**. Para o Compose local, use `192.168.1.25:3333`, substituindo o IP pelo da máquina. Para um backend no Render, use `https://meu-backend.onrender.com` ou o domínio sem o prefixo. O app acrescenta `/api` quando necessário. O endereço fica em memória enquanto o app estiver aberto. O emulador começa com `http://10.0.2.2:3333`.

```sh
cd mobile-registry
flutter pub get
flutter run
```

Entre com uma conta administrativa do Express. A sessão fica em memória e abrir o aplicativo após encerrar o processo exige novo login.

No celular físico, abra `http://<IP-do-Windows>:3333/api/health` no navegador antes de entrar. Use o IPv4 indicado por `ipconfig` no adaptador conectado à mesma rede do celular. Se o Ubuntu no WSL2 estiver em modo NAT e a porta só responder dentro do Ubuntu, encaminhe a porta TCP no Windows para o IP interno do WSL e permita a entrada no firewall. O endereço inicial ainda pode ser definido no build com `--dart-define=API_BASE_URL=http://192.168.0.10:3333/api`. [Rede do WSL2](https://learn.microsoft.com/en-us/windows/wsl/networking)

O app usa Dio para a API e `image_picker` para tirar fotos. A navegação, o estado da sessão e o estado da lista usam recursos do Flutter. A localização dos componentes Material em português é fornecida pelo SDK.

Para validar manualmente, crie um usuário, capture um JPEG e confirme o consentimento. Verifique no formulário o estado do rosto e o NFC pendente de gravação. Em seguida, abra o usuário pela lista, edite um dado e teste a exclusão. Para reproduzir um cadastro parcial, envie uma foto sem rosto e refaça o envio pelo detalhe após a mensagem de erro.

## Testes

```sh
flutter analyze
flutter test
flutter build apk --debug
```

Os documentos em `docs/` registram etapas anteriores e podem descrever telas e ferramentas já removidas.
