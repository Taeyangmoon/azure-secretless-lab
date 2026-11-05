const { test } = require('node:test');
const assert = require('node:assert');
const { createApp, findSuspiciousEnv } = require('../src/app');

async function withServer(options, fn) {
  const server = createApp(options).listen(0);
  try {
    await fn(`http://127.0.0.1:${server.address().port}`);
  } finally {
    server.close();
  }
}

test('/health returns ok', async () => {
  await withServer({ getSecret: async () => 'x', env: {} }, async (base) => {
    const body = await (await fetch(`${base}/health`)).json();
    assert.strictEqual(body.status, 'ok');
  });
});

test('/api/secret returns the Key Vault value', async () => {
  await withServer({ getSecret: async () => 'hello', env: {} }, async (base) => {
    const body = await (await fetch(`${base}/api/secret`)).json();
    assert.strictEqual(body.value, 'hello');
  });
});

test('/api/secret returns 502 with a hint on failure', async () => {
  const getSecret = async () => { throw new Error('403 Forbidden'); };
  await withServer({ getSecret, env: {} }, async (base) => {
    const res = await fetch(`${base}/api/secret`);
    assert.strictEqual(res.status, 502);
    assert.ok((await res.json()).hint);
  });
});

test('detects secret-looking environment variable names', () => {
  assert.deepStrictEqual(
    findSuspiciousEnv({ AZURE_CLIENT_ID: 'a', DB_PASSWORD: 'b', STORAGE_ACCOUNT_KEY: 'c', KEY_VAULT_URL: 'd' }),
    ['DB_PASSWORD', 'STORAGE_ACCOUNT_KEY'],
  );
});

test('/api/info reports whether the app is secretless', async () => {
  const env = { AZURE_CLIENT_ID: 'id', APP_VERSION: 'abc123' };
  await withServer({ getSecret: async () => 'x', env }, async (base) => {
    const body = await (await fetch(`${base}/api/info`)).json();
    assert.strictEqual(body.secretless, true);
    assert.strictEqual(body.version, 'abc123');
  });
});
