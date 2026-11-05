# Module 2. Deploy infrastructure (15 min)

Use Bicep to create the Azure resources for the lab. **This step creates zero secrets.**

## 1. Read the code first (5 min)

Open [`infra/main.bicep`](../../infra/main.bicep) and find the following.

| Find | Where | Meaning |
|---|---|---|
| `adminUserEnabled: false` | ACR | Registry username/password disabled |
| `enableRbacAuthorization: true` | Key Vault | Azure RBAC instead of access policies |
| `Microsoft.ManagedIdentity/userAssignedIdentities` | `appIdentity` | The identity the app will use |
| `acrPullAssignment`, `kvSecretsUserAssignment` | Role assignments | Grant the app identity **only the permissions it needs** |
| `registries: [{ identity: ... }]` | Container App | ACR pull via Managed Identity too |
| `env: [...]` | Container App | `AZURE_CLIENT_ID`, `KEY_VAULT_URL` — all **non-secret identifiers/addresses** |

> ❓ **Question:** There's an `AZURE_CLIENT_ID` environment variable — isn't that a secret?
> No. It's just an **ID that points to** which identity to use. Tokens are issued only inside the Azure platform.

## 2. Deploy (5 min)

```bash
./scripts/01-deploy-infra.sh
```

You can change the name/region with environment variables (default region: `koreacentral`).

```bash
RG=rg-secretless-<yourname> LOCATION=koreacentral ./scripts/01-deploy-infra.sh
```

> ⚠️ If you changed the resource group name, pass the same `RG=` to every later script.

When the deployment finishes, note the `url` in the output. For now, a **placeholder image** (a Microsoft sample) is running.

```bash
az deployment group show -g rg-secretless-lab -n main --query properties.outputs.appUrl.value -o tsv
```

## 3. Check in the portal (5 min)

[Azure Portal](https://portal.azure.com) ▸ resource group `rg-secretless-lab`

1. **Container Registry ▸ Settings ▸ Access keys** → confirm *Admin user* is **Disabled**
2. **Key Vault ▸ Access control (IAM) ▸ Role assignments** → confirm `secretless-id-app` has `Key Vault Secrets User`
3. **Container App ▸ Settings ▸ Identity** → confirm `secretless-id-app` is on the *User assigned* tab
4. **Container App ▸ Settings ▸ Secrets** → confirm it is **empty** 🎉

You can also check with the CLI.

```bash
az containerapp secret list -g rg-secretless-lab -n secretless-app -o table
az acr show -n <acrName> --query adminUserEnabled
```

## ✅ Checkpoint

- [ ] The deployment succeeded and `rg-secretless-lab` shows 7–8 resources
- [ ] ACR admin user = `false`
- [ ] The Container App's Secrets list is empty

Next: [Module 3. Connect GitHub ↔ Azure with OIDC](03-setup-oidc.md)
