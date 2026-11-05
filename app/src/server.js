const { DefaultAzureCredential } = require('@azure/identity');
const { SecretClient } = require('@azure/keyvault-secrets');
const { createApp } = require('./app');

const vaultUrl = process.env.KEY_VAULT_URL;

// DefaultAzureCredential 은 환경에 따라 알아서 인증 수단을 고른다.
//  - Azure(Container Apps): Managed Identity (AZURE_CLIENT_ID 로 user-assigned 지정)
//  - 로컬 개발: az login 으로 로그인한 개발자 계정
// 코드 어디에도 키/비밀번호가 등장하지 않는 것이 핵심이다.
const credential = new DefaultAzureCredential();
const client = vaultUrl ? new SecretClient(vaultUrl, credential) : null;

async function getSecret(name) {
  if (!client) throw new Error('KEY_VAULT_URL 환경변수가 설정되지 않았습니다.');
  const secret = await client.getSecret(name);
  return secret.value;
}

const port = process.env.PORT || 3000;
createApp({ getSecret }).listen(port, () => console.log(`Listening on :${port}`));
