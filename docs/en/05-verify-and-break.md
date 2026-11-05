# Module 5. Verify & break it (20 min)

Security is understood by **breaking it**. You'll misconfigure things on purpose to see which errors appear and why.
**Always restore** the original state after each exercise.

---

## Exercise A. Audit that there really are no secrets (5 min)

```bash
# 1) Secrets stored in GitHub
gh secret list

# 2) Secrets stored in the Container App
az containerapp secret list -g rg-secretless-lab -n secretless-app

# 3) Environment variables (are there any secret values?)
az containerapp show -g rg-secretless-lab -n secretless-app \
  --query "properties.template.containers[0].env[].{name:name, value:value}" -o table

# 4) ACR admin
az acr show -n <acrName> --query adminUserEnabled

# 5) Any passwords in the repository?
git grep -inE "password|secret|connection ?string" -- . ':!docs' ':!README.md' ':!README.en.md' ':!app/package-lock.json'
```

| Item | Expected result |
|---|---|
| GitHub Secrets | Empty |
| Container App Secrets | Empty |
| Environment variables | Only `AZURE_CLIENT_ID`, `KEY_VAULT_URL`, `SECRET_NAME`, `APP_VERSION` |
| ACR admin | `false` |

> Matches for `secret` in #5 are just Key Vault secret *names/comments*, not values.

---

## Exercise B. Subject mismatch — no login from another environment (5 min)

> **Hypothesis:** The Federated Credential trusts only `environment:prod`. A job running in any other environment should fail to log in.

1. In `.github/workflows/deploy.yml`, change `environment: prod` to `environment: staging` and push.
2. On the Actions tab, confirm the `Azure login (OIDC)` step **fails**.

Expected error:

```
AADSTS700213: No matching federated identity record found for presented assertion
subject 'repo:<owner>/<repo>:environment:staging'.
Check your federated identity credential Subject, Audience and Issuer against the presented assertion.
```

3. Compare the `subject` in the error message with the subject you registered in Azure.
4. **Restore:** change it back to `environment: prod` and push.

> 💡 **Lesson:** Azure trusts not "people in this repository" but "**jobs that ran in this environment of this repository**." Someone else's fork has a different subject and cannot get through.

---

## Exercise C. Remove the `id-token: write` permission (3 min)

1. Delete the `id-token: write` line at the top of `deploy.yml` and push.
2. Expected error:

```
Error: Unable to get ACTIONS_ID_TOKEN_REQUEST_URL env variable
```

3. **Restore:** add it back.

> 💡 An OIDC token is issued **only when the workflow explicitly requests it**. The default is "cannot issue" = a safe default.

---

## Exercise D. Revoke the app's permission — verify RBAC works (5 min)

Remove the app's Key Vault access.

```bash
APP_URL=$(az deployment group show -g rg-secretless-lab -n main --query properties.outputs.appUrl.value -o tsv)
KV=$(az deployment group show -g rg-secretless-lab -n main --query properties.outputs.keyVaultName.value -o tsv)
APP_PID=$(az identity show -g rg-secretless-lab -n secretless-id-app --query principalId -o tsv)
KV_ID=$(az keyvault show -n $KV --query id -o tsv)

az role assignment delete --assignee $APP_PID --role "Key Vault Secrets User" --scope $KV_ID
```

> Role changes may take **1–2 minutes** to take effect.

```bash
curl -s $APP_URL/api/secret | python3 -m json.tool
```

Expected result: HTTP 502, with `Forbidden` / `does not have secrets get permission` in `detail`.

**Restore:**

```bash
az role assignment create --assignee-object-id $APP_PID --assignee-principal-type ServicePrincipal \
  --role "Key Vault Secrets User" --scope $KV_ID
```

After 1–2 minutes, confirm `/api/secret` succeeds again.

> 💡 **Lesson:** Access control lives in **Azure RBAC**, not in app code or configuration. Revoking a permission blocks access immediately without a redeploy. There's no key rotation to do either.

---

## Exercise E. See the sign-in trail in Entra logs (2 min)

Azure Portal ▸ **Microsoft Entra ID ▸ Monitoring ▸ Sign-in logs ▸ Service principal sign-ins / Managed identity sign-ins**

- Find the sign-in record for `secretless-id-github` (GitHub Actions).
- The authentication method is shown as *Federated identity credential*.

Because the logs record who signed in, when, and from where, **auditing** is easier than with shared secrets.

---

## 🏆 Challenges (if you have time left)

1. **Separate identity for PRs:** If you want `ci.yml` to do read-only Azure work on `pull_request`, create a separate Federated Credential with subject `repo:<owner>/<repo>:pull_request` and a `Reader` identity. (Why shouldn't PRs get Contributor?)
2. **Add Storage:** Add a Storage Account to the Bicep with `allowSharedKeyAccess: false`, grant the app `Storage Blob Data Reader`, and read a blob with `@azure/storage-blob` + `DefaultAzureCredential`.
3. **Reduce permissions further:** Split the deploy identity's `Contributor` into narrower roles such as `AcrPush` + `Container Apps Contributor`.
4. **Approval gate:** Add Required reviewers to the `prod` environment and watch the deployment flow.

Next: [Module 6. Cleanup](06-cleanup.md)
