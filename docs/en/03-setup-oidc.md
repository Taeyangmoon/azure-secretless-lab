# Module 3. Connect GitHub ↔ Azure with OIDC (15 min)

This module is the heart of the lab. You configure **which GitHub workflows Azure should trust**.

## 1. Set it up in one go

Run it with your fork's name (`<owner>/<repo>`).

```bash
./scripts/02-setup-oidc.sh <owner>/<repo>
# e.g. ./scripts/02-setup-oidc.sh octocat/azure-secretless-lab
```

Let's walk through what the script does.

### ① Create the deployment Managed Identity

```bash
az identity create --name secretless-id-github --resource-group rg-secretless-lab
```

> 💡 You can attach a Federated Credential to a user-assigned Managed Identity instead of an App Registration (service principal).
> It doesn't require Entra ID app registration permissions, which makes it the most reliable option for lab environments.

### ② Register the Federated Credential ⭐

```bash
az identity federated-credential create \
  --name github-prod \
  --identity-name secretless-id-github \
  --resource-group rg-secretless-lab \
  --issuer https://token.actions.githubusercontent.com \
  --subject repo:<owner>/<repo>:environment:prod \
  --audiences api://AzureADTokenExchange
```

What this single command means:

> "If a token signed by GitHub (`issuer`) is presented by a job (`subject`) that ran in the **`prod` environment of the `<owner>/<repo>` repository**, accept it as this identity (`secretless-id-github`)."

### ③ Role assignment (least privilege)

```bash
az role assignment create --role Contributor --scope <resource group ID> \
  --assignee-object-id <principalId> --assignee-principal-type ServicePrincipal
```

Permissions are granted only at the **resource group scope**, not the whole subscription. If the pipeline is compromised, the blast radius is limited to this RG.

### ④ Register GitHub variables

`gh variable set` registers the following **Variables** and creates the `prod` environment.

| Name | Purpose |
|---|---|
| `AZURE_CLIENT_ID` | Client ID of the deploy identity |
| `AZURE_TENANT_ID` | Entra tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Subscription ID |
| `AZURE_RESOURCE_GROUP` | Resource group name |
| `ACR_NAME` | Registry name |
| `CONTAINER_APP_NAME` | Container App name |

## 2. Check the result

**GitHub side**

```bash
gh variable list      # You should see 6 variables
gh secret list        # ⭐ It should be empty!
```

Or open **Settings ▸ Secrets and variables ▸ Actions** in your repository and confirm the `Secrets` tab is **empty**.

**Azure side**

```bash
az identity federated-credential list \
  --identity-name secretless-id-github -g rg-secretless-lab -o table
```

Portal: **Managed Identity `secretless-id-github` ▸ Settings ▸ Federated credentials**

## 3. (Optional) Add an environment protection rule

Because the `subject` uses `environment:prod`, you can combine it with GitHub environment protection rules.

Add yourself (or a teammate) under **Settings ▸ Environments ▸ prod ▸ Required reviewers**, and deployments will need **manual approval**.
Without approval, the OIDC token is never even issued.

## ✅ Checkpoint

- [ ] `gh secret list` is empty
- [ ] `gh variable list` shows 6 variables
- [ ] In the Azure portal, the subject of Federated credential `github-prod` matches your repository
- [ ] `prod` exists under Settings ▸ Environments in your repository

> ⚠️ If `gh` failed and the script only printed the values, add them manually on the **Variables** tab and create the `prod` environment by hand.

Next: [Module 4. Run the CI/CD pipeline](04-pipeline.md)
