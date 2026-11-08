# frontend

Interface web de administração do **access-control** (React, TypeScript e Vite).
Cobre o Épico 6 do `scrum/BACKLOG.md`.

## Como rodar

```bash
cp .env.example .env     # ajuste BACKEND_URL se o backend não estiver em localhost:3000
npm install
npm run dev              # http://localhost:5173
```

O Vite encaminha `/api` para o backend, então o front usa caminho relativo e não depende de IP (US-17).
Outros comandos: `npm run typecheck` e `npm run build`.

### Sem backend (modo demonstração)

```bash
npm run dev:mock
```

A API é simulada no navegador, com usuários, locais, terminais, autorizações e histórico de exemplo.
Entre com **admin@teste.com** e qualquer senha. Os dados voltam ao início ao recarregar a página.
O código está em `src/shared/mock.ts` e não entra na build normal.

## O que já está pronto

| User story | Tela / arquivo |
| --- | --- |
| US-01, US-02 | Estrutura por funcionalidade, cliente HTTP único em `src/shared/api.ts` |
| US-03 | Login e rotas protegidas (`features/auth`, `Layout.tsx`); token só em memória |
| US-04, US-05 | Lista, criação, edição e desativação de usuários (`features/users`) |
| US-06, US-07 | Detalhe do usuário com foto autenticada, tags NFC (digitadas ou por leitor USB) e status do rosto |
| US-09 | Locais e terminais; a chave do terminal aparece uma única vez na criação |
| US-10, US-11, US-12 | Autorizações: filtros, criação com validação e cancelamento com confirmação |
| US-13 | Histórico de acessos com filtros e paginação no servidor |
| US-18, US-19 | Estados de carregamento, vazio e erro; confirmações; sem `localStorage` nem `dangerouslySetInnerHTML` |

## Ainda não feito

- Dashboard (US-15, US-16): depende de `/dashboard/*` e `/terminals/{id}/status` no backend.
- Exportação do histórico (US-14): depende de endpoint no backend.
- Foto por upload ou webcam (US-08).
- Testes automatizados (US-20): Vitest, Testing Library, MSW e Playwright.
- Nginx com proxy reverso e Dockerfile (US-17, épico DevOps).

## Pontos de atenção com o backend atual

- **Sem `/auth/login`.** Enquanto o backend responder 404, o login entra em *modo de desenvolvimento*:
  procura um administrador ativo pelo e-mail e **não confere a senha** (há um aviso na tela).
  Quando o login existir, o front já espera `POST /auth/login` → `{ accessToken, user }` e envia `Authorization: Bearer`.
  Para desligar o fallback: `VITE_DEV_AUTH=false`.
- **`createdById` e `canceledById`.** O backend ainda os exige no corpo; o front envia o id do administrador logado.
  Quando o backend ler o token, basta remover esses campos em `AuthorizationsPage.tsx`.
- **Sessão em memória.** Recarregar a página pede novo login até existir `POST /auth/refresh`.
- **Listas de seleção** (pessoas, locais, terminais) carregam até 100 itens, o máximo de `pageSize` do backend.
