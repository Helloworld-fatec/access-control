// backend/src/routes/index.ts
import { Router } from "express";
import { userRoutes } from "./user.routes.js";
import { locationRoutes } from "./location.routes.js";
import { terminalRoutes } from "./terminal.routes.js";
import { authorizationRoutes } from "./authorization.routes.js";
import { accessLogRoutes } from "./access-log.routes.js";

export const routes = Router();

const apiInfo = {
  name: "access-control API",
  status: "online",
  message: "API do Sistema Integrado de Controle de Acesso funcionando.",
  health: "/health",
  endpoints: ["/users", "/locations", "/terminals", "/authorizations", "/access-logs"],
};


const landingPage = `<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>ACCESS CONTROL // API</title>
  <style>
    :root {
      --bg: #090909;
      --surface: #141414;
      --surface-hover: #1d1d1d;
      --yellow: #facc15;
      --white: #f5f5f5;
      --gray: #a3a3a3;
      --muted: #666666;
      --border: #333333;
      --green: #a3e635;
    }

    * {
      box-sizing: border-box;
    }

    body {
      margin: 0;
      min-height: 100vh;
      display: grid;
      place-items: center;
      padding: 1.5rem;
      font-family: "Segoe UI", system-ui, sans-serif;
      background:
        radial-gradient(ellipse at top, #24200c 0%, transparent 55%),
        var(--bg);
      color: var(--white);
    }

    main {
      position: relative;
      width: 100%;
      max-width: 34rem;
      padding: 2.5rem;
      background: var(--surface);
      border: 1px solid var(--border);
      border-top: 4px solid var(--yellow);
      border-radius: 4px;
      box-shadow: 0 20px 60px rgba(0, 0, 0, .5);
      overflow: hidden;
    }

    main::after {
      content: "";
      position: absolute;
      top: 0;
      right: 0;
      width: 75px;
      height: 75px;
      background: repeating-linear-gradient(
        135deg,
        var(--yellow) 0 8px,
        #111111 8px 16px
      );
      clip-path: polygon(100% 0, 100% 100%, 0 0);
      opacity: .8;
    }

    .eyebrow {
      display: flex;
      align-items: center;
      gap: .6rem;
      margin-bottom: 1.5rem;
      color: var(--yellow);
      font-size: .7rem;
      font-weight: 800;
      letter-spacing: .2em;
      text-transform: uppercase;
    }

    .eyebrow::before {
      content: "";
      width: 8px;
      height: 8px;
      background: var(--yellow);
      transform: rotate(45deg);
    }

    h1 {
      margin: 0 0 .75rem;
      font-size: clamp(1.8rem, 6vw, 2.4rem);
      font-weight: 900;
      letter-spacing: -.06em;
      text-transform: uppercase;
    }

    h1 span {
      color: var(--yellow);
    }

    .subtitle {
      margin: 0 0 1.5rem;
      color: var(--gray);
      font-size: .9rem;
      line-height: 1.7;
    }

    .status {
      display: inline-flex;
      align-items: center;
      gap: .6rem;
      margin-bottom: 1.5rem;
      padding: .55rem .85rem;
      background: rgba(163, 230, 53, .07);
      border: 1px solid rgba(163, 230, 53, .3);
      color: var(--green);
      font-size: .75rem;
      font-weight: 800;
      letter-spacing: .08em;
      text-transform: uppercase;
    }

    .status-dot {
      width: 7px;
      height: 7px;
      border-radius: 50%;
      background: var(--green);
      box-shadow: 0 0 10px rgba(163, 230, 53, .6);
    }

    .section-title {
      display: flex;
      align-items: center;
      gap: .6rem;
      margin: 0 0 .85rem;
      color: var(--white);
      font-size: .8rem;
      font-weight: 800;
      letter-spacing: .12em;
      text-transform: uppercase;
    }

    .section-title::before {
      content: "//";
      color: var(--yellow);
      font-weight: 900;
    }

    ul {
      display: grid;
      gap: .5rem;
      margin: 0 0 1.5rem;
      padding: 0;
      list-style: none;
    }

    li {
      position: relative;
      padding: .75rem 1rem .75rem 2rem;
      background: #0d0d0d;
      border: 1px solid #292929;
      transition: border-color .2s, background .2s;
    }

    li::before {
      content: ">";
      position: absolute;
      left: .85rem;
      color: var(--yellow);
      font-weight: 900;
    }

    li:hover {
      background: var(--surface-hover);
      border-color: var(--yellow);
    }

    code {
      color: var(--yellow);
      font-family: "Cascadia Code", Consolas, monospace;
      font-size: .85rem;
      overflow-wrap: anywhere;
    }

    .health-link {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 1rem;
      padding: 1rem;
      background: var(--yellow);
      color: #111111;
      font-weight: 900;
      text-decoration: none;
      text-transform: uppercase;
      font-size: .8rem;
      letter-spacing: .04em;
      transition: background .2s, transform .2s;
    }

    .health-link:hover {
      background: #ffe566;
      transform: translateY(-2px);
    }

    .health-link span:last-child {
      font-size: 1.2rem;
    }

    footer {
      display: flex;
      justify-content: space-between;
      flex-wrap: wrap;
      gap: .5rem;
      margin-top: 1.5rem;
      padding-top: 1rem;
      border-top: 1px solid var(--border);
      color: var(--muted);
      font-size: .68rem;
      line-height: 1.6;
    }

    footer strong {
      color: var(--gray);
    }

    @media (max-width: 480px) {
      main {
        padding: 1.5rem;
      }
    }
  </style>
</head>
<body>
  <main>
    <div class="eyebrow">Security System // 2026</div>

    <h1><span>ACCESS</span><br />CONTROL</h1>

    <p class="subtitle">
      Sistema Integrado de Controle de Acesso.<br />
      ABP 2026-2 · 4º DSM · FATEC Jacareí
    </p>

    <div class="status">
      <span class="status-dot"></span>
      Todos os sistemas operacionais
    </div>

    <h2 class="section-title">Endpoints disponíveis</h2>

    <ul>
      ${apiInfo.endpoints.map((e) => `<li><code>${e}</code></li>`).join("\n      ")}
    </ul>

    <a class="health-link" href="/api/health">
      <span>Verificar integridade do servidor</span>
      <span>↗</span>
    </a>

    <footer>
      <span><strong>ACCESS CONTROL API</strong></span>
      <span>INTERFACE INFORMATIVA // JSON API</span>
    </footer>
  </main>
</body>
</html>`;


// Navegador (Accept: text/html) recebe a página; curl, Postman e o frontend recebem JSON.
routes.get("/", (_req, res) => {
  res.format({
    json: () => res.json(apiInfo),
    html: () => res.send(landingPage),
  });
});

routes.get("/health", (_req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

routes.use("/users", userRoutes);
routes.use("/locations", locationRoutes);
routes.use("/terminals", terminalRoutes);
routes.use("/authorizations", authorizationRoutes);
routes.use("/access-logs", accessLogRoutes);