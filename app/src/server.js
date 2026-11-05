const { DefaultAzureCredential } = require('@azure/identity');
const { SecretClient } = require('@azure/keyvault-secrets');
const { createApp } = require('./app');

const vaultUrl = process.env.KEY_VAULT_URL;

// DefaultAzureCredential picks the right authentication method for the environment:
//  - On Azure (Container Apps): Managed Identity (AZURE_CLIENT_ID selects the user-assigned one)
//  - Local development: the developer account signed in with `az login`
// The key point: no key or password appears anywhere in the code.
const credential = new DefaultAzureCredential();
const client = vaultUrl ? new SecretClient(vaultUrl, credential) : null;

async function getSecret(name) {
  if (!client) throw new Error('The KEY_VAULT_URL environment variable is not set.');
  const secret = await client.getSecret(name);
  return secret.value;
}

const port = process.env.PORT || 3000;
createApp({ getSecret }).listen(port, () => console.log(`Listening on :${port}`));
