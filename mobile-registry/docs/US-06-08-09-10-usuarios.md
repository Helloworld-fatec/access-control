# Usuários: listar, cadastrar, editar e ativar/desativar

Cobre as histórias **US-06** (listagem), **US-08** (dados do usuário), **US-09** (edição) e
**US-10** (ativação e desativação). Ficam para a próxima rodada: US-07 (assistente), US-11 e
US-12 (tag NFC).

## Como funciona

**Tela inicial = lista de usuários** (`GET /users`). Ao entrar (ou ao reabrir o app com sessão),
o administrador cai direto nela.

- **Barra superior:** Configurações, Sair. Botão grande **Novo usuário** no canto.
- **Busca** por nome ou documento (espera 0,4 s depois da última tecla para consultar).
- **Filtros** por perfil (Todos, Administrador, Condômino, Visitante) e situação (Todas, Ativos,
  Inativos), com botões grandes. Ficam **recolhidos** atrás do botão **Filtros**, para a lista
  aparecer logo na primeira tela; o botão sempre mostra o resumo do que está aplicado
  (ex.: "Condômino | Inativos").
- **Cartões** com nome, e-mail, documento, perfil, situação (Ativo/Inativo, com ícone e texto) e,
  quando a API informa, "Com/Sem tag NFC" e "Com/Sem rosto". Cada cartão é lido por leitores de
  tela como uma frase só.
- **Paginação:** 20 por vez, botão "Carregar mais". Puxar para baixo atualiza.
- **Estados:** carregando (com texto), lista vazia (com atalho "Limpar filtros" quando há
  filtro), erro (com "Tentar novamente"), e erro ao carregar mais (a lista fica).

**Cadastro** (botão Novo usuário, `POST /users`): nome, documento (opcional), e-mail, telefone
(opcional), perfil, senha (mínimo 6) com "Mostrar senha". Validação básica no app; o resto é do backend.

**Edição** (tocar em um cartão, `GET /users/{id}` e `PUT /users/{id}`): mostra os dados atuais, envia
só o que mudou e **só salva depois de uma confirmação**. Senha em branco mantém a atual.

**Ativar/desativar** (na tela de edição, `PATCH /users/{id}/status`): desativar pede confirmação
informando que o **histórico é preservado**; usuário inativo aparece identificado na lista e tem o
botão **Reativar**. O administrador não pode desativar a própria conta.

## Decisões e pontos de atenção

| Assunto | O que foi feito | Por quê |
|---|---|---|
| E-mail é obrigatório | O formulário exige e-mail; telefone é opcional | O backend exige e-mail (`createUserSchema`) e ele é o "usuário" do login. O backlog dizia "e-mail ou telefone" |
| "Usuário e senha" | O usuário de login é o próprio e-mail | `POST /auth/login` usa e-mail e senha |
| Tag/rosto na lista | App pronto; indicadores só aparecem se a API enviar | A listagem do backend não devolve esses dados (ver `docs/backend-lista-usuarios.md`) |
| Apagar documento/telefone | O app avisa que não é possível | O backend ignora campo opcional em branco no `PUT` |
| Erros por campo | Erros 400 aparecem sob o campo; somem ao editá-lo | `details: [{path, message}]` |
| Conflito (409) | Aviso geral; marca o e-mail só se o documento estava em branco | A mensagem do backend não diz qual campo repetiu |
| Senha | Nunca é aparada nem registrada | Espaços fazem parte da senha |
| Duplicar cadastro | Timeout de resposta no POST não é repetido | Regra do cliente HTTP (US-03) |
| Troca de sessão | A lista é esvaziada ao sair/entrar | Nunca mostrar dados de outro administrador |

## Limites desta etapa

- Na edição, a seção **Tag NFC e rosto** só **mostra** a situação (UID da tag, rosto cadastrado ou
  não). Vincular, remover e substituir tag (US-11/US-12) e cadastrar o rosto (US-13 a US-17) chegam
  nas próximas etapas, e a mensagem na tela avisa isso.
- O botão **Novo usuário** abre um formulário de uma etapa. Na US-07 ele vira o assistente por etapas
  (dados, tag, rosto, revisão), reaproveitando este formulário como primeira etapa.
- Pelo cliente atual, "Carregar mais" é um botão (não rolagem infinita), de propósito: é mais fácil
  de usar e de testar.

## Testar à mão

```bash
dart run tool/dev_auth_server.dart        # API de teste em memória, porta 3000
```

Entre com `admin@teste.com`. O servidor tem 25 usuários de exemplo (ativos, inativos, com e sem tag
e rosto), valida os campos e responde 400/409 como o backend. Os dados somem ao reiniciá-lo.
Rota `/api/dev/expire-tokens` invalida os tokens para você ver a expiração de sessão (US-05) na lista.

## Arquivos

Novos: `features/users/**` (modelos, repositório, controlador, lista, cartão, formulário, validadores,
seletor de perfil), `core/widgets/confirm_dialog.dart`, testes de usuários, `docs/*`.

Alterados: `features/home/presentation/home_screen.dart` (agora a lista), `core/router/app_router.dart`
(rotas `/users/new` e `/users/:id`), `tool/dev_auth_server.dart` (API de usuários), e os testes
`login_screen_test`, `logout_flow_test`, `home_screen_test`.
