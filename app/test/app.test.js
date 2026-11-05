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

test('/health 는 ok 를 반환한다', async () => {
  await withServer({ getSecret: async () => 'x', env: {} }, async (base) => {
    const body = await (await fetch(`${base}/health`)).json();
    assert.strictEqual(body.status, 'ok');
  });
});

test('/api/secret 은 Key Vault 값을 반환한다', async () => {
  await withServer({ getSecret: async () => 'hello', env: {} }, async (base) => {
    const body = await (await fetch(`${base}/api/secret`)).json();
    assert.strictEqual(body.value, 'hello');
  });
});

test('/api/secret 은 실패 시 502 와 힌트를 반환한다', async () => {
  const getSecret = async () => { throw new Error('403 Forbidden'); };
  await withServer({ getSecret, env: {} }, async (base) => {
    const res = await fetch(`${base}/api/secret`);
    assert.strictEqual(res.status, 502);
    assert.ok((await res.json()).hint);
  });
});

test('시크릿처럼 보이는 환경변수 이름을 탐지한다', () => {
  assert.deepStrictEqual(
    findSuspiciousEnv({ AZURE_CLIENT_ID: 'a', DB_PASSWORD: 'b', STORAGE_ACCOUNT_KEY: 'c', KEY_VAULT_URL: 'd' }),
    ['DB_PASSWORD', 'STORAGE_ACCOUNT_KEY'],
  );
});

test('/api/info 는 secretless 여부를 알려준다', async () => {
  const env = { AZURE_CLIENT_ID: 'id', APP_VERSION: 'abc123' };
  await withServer({ getSecret: async () => 'x', env }, async (base) => {
    const body = await (await fetch(`${base}/api/info`)).json();
    assert.strictEqual(body.secretless, true);
    assert.strictEqual(body.version, 'abc123');
  });
});
