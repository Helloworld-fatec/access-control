# Assistente de cadastro (US-07), leitura de NFC (US-11) e gestão de tags (US-12)

## Novidades

**US-11: leitura de tag NFC.** Diálogo "Ler tag NFC" (`features/nfc/presentation/nfc_capture_dialog.dart`):
instrução enquanto espera a tag, resultado de sucesso ou falha, nova tentativa e cancelamento. O UID sai
no **mesmo padrão do mobile-readings e do backend**: hexadecimal em maiúsculas, sem separadores, mesma
ordem de bytes (`04A32F1B`). Usa o mesmo plugin e a mesma versão do mobile-readings (`nfc_manager ^3.5.0`).

**US-12: vincular, substituir e remover tag**, na tela de edição do usuário (seção "Tag NFC e rosto"):

- **Vincular** (`POST /users/{id}/tags`): lê a tag, mostra o código e só vincula depois do "Usar esta tag".
- **Substituir:** lê a nova tag e pede confirmação ("A tag X deixará de funcionar e a tag Y passará a valer").
- **Remover** (`DELETE /users/{id}/tags/{tagId}`): pede confirmação.
- **Um usuário pode ter mais de uma tag** (o backend permite); cada uma tem Substituir e Remover.
- **UID de outra pessoa (409):** a mensagem é fixa, "Esta tag já está cadastrada.", e nunca repassa texto
  do servidor que possa identificar o dono.

**US-07: assistente de cadastro** (botão **Novo usuário**), com indicador "Etapa X de 4":

1. **Dados** (os campos da US-08, validados antes de avançar);
2. **Tag NFC** (opcional, "Pular esta etapa");
3. **Rosto** (opcional; a captura chega nas próximas etapas, a tela avisa);
4. **Revisão** (tudo o que será enviado; a senha não é mostrada) e **Confirmar cadastro**.

"Voltar" mantém tudo o que foi digitado. O botão voltar do aparelho volta uma etapa (e, na primeira, sai).

## Decisões importantes

| Assunto | O que foi feito | Por quê |
|---|---|---|
| Ordem ao substituir tag | **Vincula a nova primeiro, remove a antiga depois** | Se a nova der conflito ou falhar, o usuário continua com a tag que tinha (nunca fica sem acesso). Se a nova entrar e a remoção falhar, a tela avisa e mostra as duas |
| Ordem ao cadastrar | **Cria o usuário primeiro, vincula a tag em seguida** | A tag precisa do id do usuário. Se a tag falhar, o cadastro **não é perdido**: um aviso oferece "Abrir cadastro" (edição) ou "Fechar" |
| Erro nos dados ao confirmar | Volta à etapa 1 com o erro sob o campo e os dados preservados | É onde o campo se corrige |
| Remover tag que já não existe (404) | Conta como removida | O resultado desejado foi alcançado (ex.: a 1ª tentativa funcionou e só a resposta se perdeu) |
| Código digitado | Opção "Digitar o código manualmente" | Aparelhos sem NFC, ou NFC desligado, ainda conseguem vincular; também ajuda em testes |
| UID válido | 8 a 20 caracteres hexadecimais, número par | Limites do backend (4 a 10 bytes) |
| NFC desligado × sem NFC | Mesma mensagem: "pode não ter NFC ou ele está desligado" | A API do Android (`isAvailable`) não distingue os dois casos |
| Timeout de leitura | 30 s, com mensagem para tentar de novo | Evita ficar esperando para sempre |

## Mudanças de estrutura

- `UserFormScreen` agora é **só a edição** (`userId` obrigatório). O cadastro é a `NewUserWizardScreen`.
- Os campos de dados viraram o widget `UserDataFields`, com o estado em `UserFormModel`, usados pelo
  assistente (etapa 1) e pela edição. Assim a lógica de erros por campo existe uma vez só.
- A rota `/users/new` abre o assistente; `/users/:id` abre a edição.

## Como testar

1. `flutter pub get` (nova dependência: `nfc_manager`).
2. **Celular real com NFC.** Emulador não lê NFC (aparece "NFC indisponível"; use "Digitar o código manualmente").
3. `dart run tool/dev_auth_server.dart`: agora aceita `POST /users/{id}/tags` e `DELETE /users/{id}/tags/{tagId}`
   (UID repetido entre usuários devolve 409), em memória.
4. No app: **Novo usuário**, preencha, avance até **Tag NFC**, toque em **Ler tag NFC** e aproxime uma tag
   da parte de trás do celular. Para substituir/remover, abra o usuário na lista.

## Limites desta etapa

- O **cadastro do rosto** (US-13 a US-17) ainda não existe: a etapa 3 e a seção de rosto só informam isso.
- Não há "abrir configurações do NFC" direto do app (exigiria outro plugin): a mensagem orienta o usuário.
- Se o backend vier a limitar o número de tags por usuário, o app mostrará a mensagem de erro dele.

## Arquivos

Novos: `core/nfc/*` (UID e leitor), `features/nfc/presentation/nfc_capture_dialog.dart`,
`features/users/presentation/{new_user_wizard_screen,user_data_fields,user_form_model,user_credentials_section,wizard_progress,wizard_steps,form_notice}.dart`,
testes correspondentes e `test/helpers/fake_nfc_service.dart`.

Alterados: `pubspec.yaml`, `user_form_screen.dart`, `users_repository.dart` (`addTag`, `removeTag`, `replaceTag`),
`user_models.dart` (`withTags`), `app_router.dart`, `tool/dev_auth_server.dart`, e os testes
`user_form_screen_test`, `users_repository_test`, `user_models_test`, `home_screen_test`, `test_app`.
