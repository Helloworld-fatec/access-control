# Pauta de esclarecimentos com o professor

Dúvidas de requisitos e escopo a alinhar com o prof. Leandro Toss Hoffmann. A pauta nasceu antes da Sprint Review 1 (21/10/2026) e foi atualizada em 22/11/2026, antes da Sprint Review 3 (25/11/2026, 19h30). Cada item traz a proposta do grupo para facilitar a decisão.

## Situação em 22/11/2026

| # | Tema | Situação |
|---|---|---|
| 1 | Reconhecimento facial: obrigatório ou extra? | Sem decisão do professor registrada. O time seguiu com o facial como extra e o implementou na Sprint 3 (microserviço de reconhecimento e captura no terminal) |
| 2 | Raio de proximidade do QR Code | Sem decisão registrada. O backend ainda não valida a distância |
| 3 | Banco de dados e deploy em nuvem | Sem decisão registrada. Não há evidência de banco em nuvem no repositório |
| 4 | Administração no aplicativo móvel | Sem decisão registrada. Locais e autorizações seguem no frontend |
| 5 | Leitor NFC no ESP32 | **Decidido pelo professor** e aplicado na arquitetura e no mobile-readings |
| 6 | Receptor GPS do terminal | **Decidido na Review 1** (ver o item 6) |
| 7 | Login do visitante | Sem decisão registrada |
| 8 | Comportamento da trava sem energia | Sem decisão registrada |
| 9 | Plataforma dos aplicativos móveis | Sem decisão registrada. Os apps são desenvolvidos para Android |

### Para levar à Review 3

Os itens abaixo ainda não têm resposta do professor registrada e afetam a entrega final:

1. **Proximidade do QR (item 2):** pelo menos ou no máximo 100 m, e qual raio usar.
2. **Banco e deploy em nuvem (item 3):** a demonstração local com Docker Compose atende ao RNF06 e ao RP11?
3. **Reconhecimento facial (item 1):** confirmar que é extra.
4. **Leitor RC522 do terminal:** possível falha na soldagem, para avaliação (veja [`sprint-2.md`](./sprints/sprint-2.md), seção 6).
5. **Apresentação final:** data e formato, que o professor define. Não há outro documento a escrever além da documentação técnica do repositório (RP07).

| # | Tema | Impacta |
|---|---|---|
| 1 | Reconhecimento facial: obrigatório ou extra? | mobile-readings, mobile-registry, backend |
| 2 | Raio de proximidade do QR Code | mobile-user, backend |
| 3 | Banco de dados e deploy em nuvem | backend, DevOps |
| 4 | Administração (locais e autorizações) no app móvel | mobile-registry, frontend |
| 5 | Leitor NFC no ESP32, e não no terminal (**decidido pelo professor**) | mobile-readings, mobile-registry, frontend, device-esp32, backend |
| 6 | Receptor GPS do terminal | device-esp32 |
| 7 | Login do visitante | mobile-registry, mobile-user, backend |
| 8 | Comportamento da trava sem energia | device-esp32 |
| 9 | Plataforma dos aplicativos móveis | mobile-* |

---

## 1. Reconhecimento facial: obrigatório ou extra?

**Contexto:** o enunciado fala em QR Code e NFC e não menciona reconhecimento facial. O grupo planejou o facial como funcionalidade adicional.

**Proposta do grupo:** tratar como **extra**, implementado somente depois de QR Code e NFC estarem estáveis.

**Decisão do professor:** ______________________________

---

## 2. Raio de proximidade do QR Code (RF13)

**Contexto:** o RF13 diz "proximidade geográfica de **pelo menos** 100 metros". Entendemos que a intenção é o usuário estar a **no máximo** 100 metros do terminal.

**Proposta do grupo:** validar distância **máxima** de 100 m (fórmula de Haversine), com raio configurável e considerando a precisão do GPS enviada pelo app.

**Decisão do professor:** ______________________________

---

## 3. Banco de dados e deploy em nuvem (RNF06, RP11)

**Contexto:** o enunciado pede banco em nuvem e deploy automatizado preferencialmente em nuvem. A entrega final roda **localmente com Docker Compose**, em LAN, porque o ambiente da apresentação tem conectividade instável. Durante o desenvolvimento, o backend já está publicado em uma plataforma de nuvem (Render).

**Proposta do grupo:** executar a demonstração local e apresentar o deploy em nuvem já existente como atendimento ao RP11, automatizando-o no pipeline de entrega. Confirmar se o banco também precisa estar em nuvem para atender o RNF06.

**Decisão do professor:** ______________________________

---

## 4. Administração no aplicativo móvel (RF03 a RF05)

**Contexto:** o enunciado descreve a administração do sistema e o gerenciamento de autorizações como função do aplicativo móvel. Hoje o **mobile-registry** cobre usuários, tags NFC e rosto, e locais e autorizações ficam no **frontend web**.

**Proposta do grupo:** manter locais e autorizações no frontend e usar o mobile-registry para usuários, tags e foto.

**Decisão do professor:** ______________________________

---

## 5. Leitor NFC no ESP32, e não no terminal (RF11)

**Contexto:** o RF11 lista tela e leitor NFC como parte do Terminal de Acesso. O grupo havia planejado a leitura de NFC no celular do terminal (mobile-readings).

**Decisão do professor:** a leitura de tag NFC é feita por um **leitor ligado ao Arduino (ESP32)**, e não pelo terminal (app mobile-readings). O terminal exibe o QR Code e o resultado e lê a foto, sem usar NFC.

**Decisão do Product Owner (gravação):** o cadastro parte do mobile-registry ou do frontend; o backend gera um **código aleatório** e o manda ao ESP32, que o **grava na tag**. O mesmo ESP32 grava e lê.

**Impacto na arquitetura:** no acesso, o ESP32 lê o código da tag e o publica por MQTT; o backend valida e responde. Detalhes em [`docs/arquitetura.md`](../docs/arquitetura.md).

---

## 6. Receptor GPS do terminal (RF11)

**Contexto:** o RF11 exige receptor GPS, mas ele raramente obtém posição em ambiente fechado. O RP08 permite simulação de componentes físicos.

**Proposta do grupo:** cadastrar a **coordenada fixa** do terminal no backend e, se houver tempo, incluir um módulo GPS conectado ao ESP32 para comprovar o componente.

**Decisão do professor:** na Review 1 (21/10/2026), o professor disse que é importante colocar o GPS e fazer uma configuração de teste, com a localização configurada ([`sprint-1.md`](./sprints/sprint-1.md), seção 6.1). O módulo físico será testado na Sprint 3.

---

## 7. Login do visitante

**Contexto:** o visitante precisa de credencial para usar o aplicativo.

**Opções:** (a) o administrador cria o acesso com **senha temporária**; (b) o visitante recebe um **convite**.

**Proposta do grupo:** senha temporária criada pelo administrador, expirando junto com a autorização.

**Decisão do professor:** ______________________________

---

## 8. Comportamento da trava sem energia

**Contexto:** é preciso definir se a trava fica fechada (*fail-secure*) ou aberta (*fail-safe*) quando falta energia ou o dispositivo trava. Em um prédio real, a decisão envolve segurança contra incêndio.

**Proposta do grupo:** *fail-secure* na demonstração, declarando a escolha e a ressalva na documentação.

**Decisão do professor:** ______________________________

---

## 9. Plataforma dos aplicativos móveis (RP04)

**Contexto:** instalar em iPhone exige conta de desenvolvedor ou TestFlight, e a leitura de NFC em segundo plano é limitada no iOS.

**Proposta do grupo:** desenvolver e demonstrar em **Android**, com instalação direta do APK.

**Decisão do professor:** ______________________________
