const express = require('express');

// 환경변수 "이름"에 이 패턴이 들어 있으면 시크릿이 숨어 있을 가능성이 있다고 본다.
const SUSPICIOUS_ENV = /(SECRET|PASSWORD|PASSWD|TOKEN|CONNECTION_?STRING|ACCESS_?KEY|ACCOUNT_?KEY|API_?KEY)/i;

function findSuspiciousEnv(env) {
  return Object.keys(env).filter((name) => SUSPICIOUS_ENV.test(name));
}

function createApp({ getSecret, env = process.env }) {
  const app = express();

  app.get('/health', (_req, res) => res.json({ status: 'ok' }));

  app.get('/api/info', (_req, res) => {
    const suspicious = findSuspiciousEnv(env);
    res.json({
      version: env.APP_VERSION || 'local',
      hostname: env.HOSTNAME || 'unknown',
      authMode: env.AZURE_CLIENT_ID ? 'user-assigned managed identity' : 'developer credential (az login)',
      keyVaultUrl: env.KEY_VAULT_URL || null,
      secretLikeEnvVars: suspicious,
      secretless: suspicious.length === 0,
    });
  });

  app.get('/api/secret', async (_req, res) => {
    const name = env.SECRET_NAME || 'demo-message';
    try {
      const value = await getSecret(name);
      res.json({ name, value, source: 'Azure Key Vault (Managed Identity)' });
    } catch (err) {
      res.status(502).json({
        error: 'Key Vault 에서 시크릿을 읽지 못했습니다.',
        detail: err.message,
        hint: 'Managed Identity 에 "Key Vault Secrets User" 역할이 부여되었는지 확인하세요.',
      });
    }
  });

  app.get('/', (_req, res) => {
    res.type('html').send(`<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <title>Secretless Lab</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 720px; margin: 3rem auto; padding: 0 1rem; }
    pre { background: #f4f4f4; padding: 1rem; border-radius: 6px; overflow-x: auto; }
    button { padding: .5rem 1rem; margin-right: .5rem; }
  </style>
</head>
<body>
  <h1>🔐 Azure Secretless CI/CD Lab</h1>
  <p>이 앱에는 <b>비밀번호, 연결 문자열, 클라이언트 시크릿이 하나도 없습니다.</b></p>
  <button onclick="load('/api/info')">/api/info</button>
  <button onclick="load('/api/secret')">/api/secret</button>
  <pre id="out">버튼을 눌러보세요.</pre>
  <script>
    async function load(path) {
      const r = await fetch(path);
      document.getElementById('out').textContent = JSON.stringify(await r.json(), null, 2);
    }
  </script>
</body>
</html>`);
  });

  return app;
}

module.exports = { createApp, findSuspiciousEnv };
