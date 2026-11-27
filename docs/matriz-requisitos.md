# Matriz de requisitos

Estado de cada requisito do Desafio 4DSM 2026-2 na `main` em **15/11/2026** (commit `15aa291`). A lista de requisitos está no [README](../README.md). A matriz foi montada pela leitura do código e da documentação de cada serviço, e rodando o `npm test` do backend. Os aplicativos e o firmware **não foram executados** nesta conferência, então cada responsável deve validar as linhas do seu serviço.

**Status**

- **Atendido:** implementado e coerente com o requisito. A coluna de evidência diz se há teste ou demonstração.
- **Parcial:** parte do requisito está implementada, e a lacuna está descrita.
- **Não atendido:** nada implementado.
- **Não comprovado:** não há evidência no repositório.

## Resumo

| | Atendido | Parcial | Não atendido | Não comprovado |
|---|---|---|---|---|
| Funcionais (17) | 11 | 6 | 0 | 0 |
| Não funcionais (12) | 3 | 7 | 1 | 1 |

## Requisitos funcionais

| ID | Requisito | Status | Evidência e lacuna |
|---|---|---|---|
| RF01 | Cadastro de usuários nos três perfis | Atendido | `POST /api/users` com `ADMIN`, `RESIDENT` e `VISITOR` ([api.md](./api.md)); telas de usuários no `frontend` e no `mobile-registry` |
| RF02 | Cadastro de locais de acesso | Atendido | `/api/locations` com edifício, portaria, porta e catraca; tela de locais no `frontend` |
| RF03 | Criação de autorização | Atendido | `POST /api/authorizations` com pessoa, local, datas, horários e usos; tela de criação no `frontend` |
| RF04 | Consulta de autorizações com filtros | Atendido | `GET /api/authorizations` com usuário, local, situação e período; lista com filtros no `frontend` |
| RF05 | Cancelamento de autorização | Atendido | `PATCH /api/authorizations/:id/cancel`; cancelamento com confirmação no `frontend` |
| RF06 | Histórico de acessos | Atendido | `GET /api/access-logs` com filtros e paginação; tela de histórico no `frontend` |
| RF07 | Autenticação do usuário no app | Atendido | `POST /api/login`; o `mobile-user` e o `mobile-registry` chamam o login. Não houve demonstração com o backend registrada |
| RF08 | Consulta das autorizações pelo usuário | Atendido | `GET /api/authorizations/me`; o `mobile-user` consome a rota. Não houve demonstração registrada |
| RF09 | Leitura do QR Code pelo app | Atendido | O `mobile-user` lê o QR com `mobile_scanner` e chama `/api/access/qr/consume`. O app não envia a localização do celular (ver RF13) |
| RF10 | Leitura de tag NFC no terminal | Parcial | O backend recebe a leitura em `/api/access/nfc` e o `mobile-readings` lê NFC. No terminal físico, o RC522 está em diagnóstico, com possível falha de soldagem, e aguarda a avaliação do professor |
| RF11 | Terminal com processamento, rede, tela, NFC, sinalização, GPS e abertura | Parcial | ESP32, OLED, sensor infravermelho, LEDs, buzzer e servo testados na bancada ([hardware](../device-esp32/hardware/README.md)). Faltam o RC522 validado, o GPS (sem teste) e a comunicação com o backend |
| RF12 | QR gerado no backend, renovado a cada 10 s | Parcial | `GET /api/terminals/:id/qr` renova a cada 10 s, mas `POST /api/terminals/me/qr`, o único que o `/access/qr/consume` aceita, gera tokens de 300 s. Os dois formatos precisam ser unificados |
| RF13 | Validação via QR com proximidade geográfica | Parcial | O backend valida o QR (validade, uso único), a autorização, o horário e os usos. A distância não é validada: o motivo `TOO_FAR` existe, mas nenhuma rota o usa, e o app não envia a localização |
| RF14 | Validação de acesso via tag NFC | Parcial | `POST /api/access/nfc` aplica as mesmas regras do QR e registra a tentativa. Depende do leitor físico (RF10) para fechar o fluxo |
| RF15 | Liberação por mecanismo físico ou simulado | Parcial | Servo acionado na bancada com autorização simulada pelo monitor serial. O backend ainda não publica o comando ao ESP32: `requestDoorUnlock` apenas registra `[MQTT SIMULADO]` |
| RF16 | Negação com indicação visual ou sonora | Atendido | LED vermelho e buzzer testados na bancada; telas de acesso liberado e negado no `mobile-readings` |
| RF17 | Registro de toda tentativa de acesso | Atendido | Tabela `access_logs` recebe QR, NFC e rosto, liberados ou negados. Exceção: um QR desconhecido responde `401` sem registro |

## Requisitos não funcionais

| ID | Requisito | Status | Evidência e lacuna |
|---|---|---|---|
| RNF01 | Dispositivo IoT, backend Node.js/TypeScript, API REST e app móvel | Atendido | Seis serviços no repositório: backend, frontend, três apps Flutter e firmware ESP32 |
| RNF02 | Segurança: autenticação, dados sensíveis e comunicação segura | Parcial | Senhas com bcrypt, JWT, QR de uso único guardado em hash, chave do terminal em hash e limite de requisições. Faltam login nas rotas de usuários, locais e histórico, restrição do CORS e comunicação MQTT protegida |
| RNF03 | Confiabilidade, com retry ou armazenamento local | Parcial | O `mobile-readings` tem retry e nega o acesso por padrão quando a rede falha, e o `mobile-registry` tem retry automático; o terminal físico ainda não tem rotina de reconexão |
| RNF04 | Usabilidade e acessibilidade, inclusive para idosos | Parcial | `frontend` com atributos de acessibilidade (`aria-*`) e tabela equivalente ao gráfico para leitores de tela; `mobile-registry` com botões grandes e alto contraste. O contraste WCAG AA do frontend foi informado pelo Pedro e não está registrado em documento. Sem teste com usuários idosos |
| RNF05 | Manutenibilidade: modularidade | Atendido | Backend em camadas (rotas, controladores, serviços, modelos), serviços separados por pasta e uma estrutura por funcionalidade no frontend e nos apps |
| RNF06 | Persistência em banco de dados em nuvem | Não comprovado | O repositório só traz o PostgreSQL local (`docker-compose.test.yml`). Não há evidência de banco em nuvem |
| RNF07 | Eficiência energética do dispositivo | Parcial | O `mobile-readings` fica em repouso até a presença ser detectada. Não há medição de consumo no ESP32 |
| RNF08 | Integração contínua a cada commit | Parcial | Há um workflow, o do `mobile-registry` (`.github/workflows/mobile-registry-ci.yml`). Backend, frontend e firmware não têm |
| RNF09 | Entrega contínua | Não atendido | Não há workflow de deploy |
| RNF10 | Testes automatizados no pipeline | Parcial | O workflow do `mobile-registry` roda os testes. Os 4 testes do backend e os testes do frontend (Vitest) rodam localmente, fora do pipeline |
| RNF11 | Controle de versão com Git | Atendido | Pull Requests, branches por funcionalidade e commits descritivos; mudanças entram na `main` por PR |
| RNF12 | Feedback de build, testes e deploy | Parcial | Só o workflow do `mobile-registry` informa o resultado. Falta nos demais serviços |

## Pendências que mais pesam

1. **Integração backend e ESP32 por MQTT** (RF11, RF15): o contrato existe em [`contrato-mqtt.md`](./contrato-mqtt.md), e a publicação no backend ainda é simulada.
2. **Proximidade geográfica** (RF13): o app precisa enviar a localização e o backend precisa calcular a distância.
3. **Unificar o QR** (RF12): um só formato, renovado a cada 10 s e aceito pelo `/access/qr/consume`.
4. **RC522 e GPS** (RF10, RF11): dependem da bancada da Bruna e da avaliação do professor.
5. **CI/CD e testes no pipeline** (RNF08 a RNF10, RNF12): trabalho da Sprint 3.
6. **Login nas rotas abertas** (RNF02).
7. **Banco em nuvem** (RNF06): confirmar se existe e documentar.
