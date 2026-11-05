# Module 4. Run the CI/CD pipeline (15 min)

## 1. Read the workflows (5 min)

### `ci.yml` — validation (no Azure access)

```yaml
permissions:
  contents: read      # Read-only. Does not talk to Azure.
```

On PRs and branch pushes it only runs tests and a Docker build. **No secrets, no cloud permissions.**

### `deploy.yml` — deployment (OIDC)

| Line | Meaning |
|---|---|
| `permissions: id-token: write` | Permission to ask GitHub for an OIDC token. **Without it, login fails** |
| `environment: prod` | Makes the token's subject `...:environment:prod` → must match the Federated Credential |
| `azure/login@v2` + `client-id / tenant-id / subscription-id` | **There is no `client-secret` input!** All values come from `vars.` (variables) |
| `az acr build` | Builds in ACR → no Docker login or registry password needed on the runner |
| `az containerapp update --image` | Deploys a new revision. The app pulls from ACR via Managed Identity |

```yaml
- uses: azure/login@v2
  with:
    client-id: ${{ vars.AZURE_CLIENT_ID }}
    tenant-id: ${{ vars.AZURE_TENANT_ID }}
    subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
    # no client-secret ⭐
```

## 2. Run the deployment (5 min)

Pushing an app change to the main branch triggers it automatically. Let's make a visible change first.

```bash
# Edit the <h1> text in app/src/app.js to include your name
sed -i 's|Azure Secretless CI/CD Lab|Azure Secretless CI/CD Lab - <your name>|' app/src/app.js

git add -A
git commit -m "feat: personalize landing page"
git push origin main
```

Or run it manually with **Actions ▸ Deploy to Azure ▸ Run workflow**.

### Watch it run

Open the running workflow on your repository's **Actions** tab.

1. When the `test` job passes,
2. the `deploy` job starts. (If you added an approval rule to the `prod` environment, approve it via **Review deployments**.)
3. Expand the **Azure login (OIDC)** step log.

```
Federated token details:
 issuer - https://token.actions.githubusercontent.com
 subjectClaim - sub
 audience - api://AzureADTokenExchange
 ...
Login successful.
```

> 🔍 There is no password anywhere in the log. This step is the **GitHub token ↔ Entra token exchange**.

4. **Build & push image** → **Deploy to Container Apps** → **Smoke test** then succeed in order.

## 3. Check the result (5 min)

The app URL (`🚀 Deployed: ...`) appears in the workflow **Summary**. You can also check from a terminal.

```bash
APP_URL=$(az deployment group show -g rg-secretless-lab -n main --query properties.outputs.appUrl.value -o tsv)
curl -s $APP_URL/api/info | python3 -m json.tool
curl -s $APP_URL/api/secret | python3 -m json.tool
```

Expected result:

```json
{
  "version": "a1b2c3d",
  "authMode": "user-assigned managed identity",
  "secretLikeEnvVars": [],
  "secretless": true
}
{
  "name": "demo-message",
  "value": "Hello from Key Vault! This value is not stored in code, environment variables, or GitHub Secrets.",
  "source": "Azure Key Vault (Managed Identity)"
}
```

Open `APP_URL` in a browser and click the buttons too.

## ✅ Checkpoint

- [ ] The `deploy.yml` run succeeded (green)
- [ ] You saw `Login successful` in the `Azure login (OIDC)` log
- [ ] `version` in `/api/info` equals the first 7 characters of your commit SHA
- [ ] `/api/secret` returns the Key Vault value

> 🤔 **Think about it:** The app read a Key Vault value, yet there are no credentials in the code or environment variables. Who authenticated that request?
> → The app obtained a Managed Identity token via `DefaultAzureCredential` and presented it to Key Vault, which checked RBAC (`Key Vault Secrets User`).

Next: [Module 5. Verify & break it](05-verify-and-break.md)
