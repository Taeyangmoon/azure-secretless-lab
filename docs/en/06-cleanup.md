# Module 6. Cleanup (5 min)

Delete the lab resources so you don't keep incurring costs.

```bash
./scripts/03-cleanup.sh <owner>/<repo>
```

What the script does:

1. Deletes the resource group `rg-secretless-lab` (ACR, Key Vault, Container Apps, Managed Identities, and Federated Credential — **all included**)
2. Deletes the 6 GitHub repository variables and the `prod` environment

Confirm deletion (takes a few minutes):

```bash
az group exists -n rg-secretless-lab   # Done when this returns false
```

> 🧹 **Key Vault soft delete:** A deleted Key Vault stays in a soft-deleted state for 7 days. If that causes problems (e.g. reusing the same name), permanently delete it with
> `az keyvault purge --name <name>`. (This lab adds a random suffix to names, so conflicts don't occur.)

## 🎓 Wrap-up — what you learned

| Question | Answer |
|---|---|
| How does GitHub Actions log in to Azure without a password? | Entra ID verifies the OIDC token against the Federated Credential (issuer/subject/audience) |
| Why is it safe to keep `client-id` and `tenant-id` in Variables? | They're identifiers, not credentials. The token is signed and issued by GitHub |
| How does the app access Key Vault? | Managed Identity + RBAC; the code uses `DefaultAzureCredential` |
| Why separate the deploy identity from the app identity? | To limit the blast radius if one is compromised (least privilege) |
| What's the biggest benefit of Secretless? | The burden of leaks, expiry, and rotation disappears |

## 📖 Learn more

- [GitHub: Configuring OpenID Connect in Azure](https://docs.github.com/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-azure)
- [Microsoft Learn: Workload identity federation](https://learn.microsoft.com/entra/workload-id/workload-identity-federation)
- [Microsoft Learn: Managed identities for Azure resources](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/overview)
- [Azure Container Apps: Managed identity](https://learn.microsoft.com/azure/container-apps/managed-identity)
- [Azure SDK: DefaultAzureCredential](https://learn.microsoft.com/azure/developer/intro/passwordless-overview)

Great job! 🎉
