# Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `AuthorizationFailed ... roleAssignments/write` (Module 2/3) | No permission to assign roles on the subscription | Request `Owner` or `User Access Administrator` |
| `MissingSubscriptionRegistration` | Resource provider not registered | Run `az provider register` from Module 0, wait 1–2 minutes |
| Bicep deployment fails with a transient error | Temporary ARM error | Re-run `./scripts/01-deploy-infra.sh` (idempotent) |
| `gh variable set` → `403 / Resource not accessible` | Codespaces `GITHUB_TOKEN` lacks permission | `unset GITHUB_TOKEN && gh auth login`, then re-run `02-setup-oidc.sh` |
| "Already exists" error when re-running `02-setup-oidc.sh` | Leftovers from a previous run | Delete the federated credential: `az identity federated-credential delete -n github-prod --identity-name secretless-id-github -g rg-secretless-lab -y`, then re-run |
| `AADSTS700213: No matching federated identity record` | Subject mismatch (repo name typo/case, environment name mismatch) | Compare the subject in the log with the Federated credential subject in Azure and fix it |
| `AADSTS700016: Application with identifier ... not found` | Wrong `AZURE_CLIENT_ID` / `AZURE_TENANT_ID` | Compare `gh variable list` with `az identity show -n secretless-id-github -g ... --query clientId` |
| `Unable to get ACTIONS_ID_TOKEN_REQUEST_URL` | Missing `permissions: id-token: write` | Add the permission to the workflow |
| `Login failed ... No subscriptions found` | Contributor role propagation delay | Retry after 1–2 minutes (Re-run jobs) |
| `deploy` stuck in `Waiting` | Required reviewers set on the `prod` environment | Approve with **Review deployments** on the Actions page |
| Workflows don't run on the fork | Actions disabled by default on forks | Enable it on the Actions tab |
| Smoke test keeps failing | New revision slow to start / port mismatch | `az containerapp logs show -g rg-secretless-lab -n secretless-app --tail 50`, `az containerapp revision list ... -o table` |
| `/api/secret` returns 502 `Forbidden` | App identity lacks the role / propagation delay | Check `Key Vault Secrets User` under Key Vault ▸ IAM in the portal, retry after 2 minutes |
| `/api/secret` returns 502 `ManagedIdentityCredential ... unavailable` | `AZURE_CLIENT_ID` not set | Check `az containerapp show ... --query "properties.template.containers[0].env"` |
| Container shows `ImagePullBackOff` / `UNAUTHORIZED` | AcrPull role propagation delay or missing | Check `AcrPull` under ACR ▸ IAM, then create a new revision |
| Key Vault name conflict (`VaultAlreadyExists`) | A soft-deleted vault with the same name | `az keyvault purge --name <name>` |

## Useful diagnostic commands

```bash
# Logs
az containerapp logs show -g rg-secretless-lab -n secretless-app --tail 50

# Revision status
az containerapp revision list -g rg-secretless-lab -n secretless-app -o table

# Federated Credentials of the deploy identity
az identity federated-credential list --identity-name secretless-id-github -g rg-secretless-lab -o table

# Roles assigned to the deploy identity
az role assignment list --assignee $(az identity show -n secretless-id-github -g rg-secretless-lab --query principalId -o tsv) \
  --all -o table
```

## Note: what if you redeploy the infrastructure?

Re-running `01-deploy-infra.sh` reverts the Container App to the **initial placeholder image**.
Run `deploy.yml` again (Actions ▸ Run workflow) to restore it.
