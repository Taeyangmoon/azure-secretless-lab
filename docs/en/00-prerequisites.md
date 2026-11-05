# Module 0. Prerequisites (10 min)

## What you need

| Item | Description |
|---|---|
| Azure subscription | Permission to create resource groups and **role assignments** (`Owner`, or `Contributor` + `User Access Administrator`) |
| GitHub account | Able to fork repositories and use Actions |
| Lab environment | **GitHub Codespaces (recommended)**, or `az`, `gh`, and `node 22` installed locally |

> 💡 You do **not** need permission to register Microsoft Entra ID apps. This lab uses Managed Identities, so subscription RBAC permissions are enough.

## 1. Fork the repository

1. On the original repository, click **Fork** ▸ **Create fork** (top right).
2. In your fork, open **Settings ▸ Actions ▸ General** and make sure Actions is enabled. (Workflows may be disabled by default in forks — click `I understand my workflows, go ahead and enable them` on the Actions tab.)

## 2. Open a Codespace

**Code ▸ Codespaces ▸ Create codespace on main**

Check the tools in the terminal.

```bash
az version
gh --version
node -v
```

## 3. Sign in to Azure

```bash
az login --use-device-code
az account show --query '{name:name, id:id, tenant:tenantId}' -o table
```

If you have multiple subscriptions, select the one for this lab.

```bash
az account set --subscription "<subscription name or ID>"
```

Register the required resource providers (one-time, 1–2 minutes).

```bash
for ns in Microsoft.App Microsoft.ContainerRegistry Microsoft.KeyVault Microsoft.OperationalInsights Microsoft.ManagedIdentity; do
  az provider register --namespace $ns
done
```

## 4. Sign in to GitHub CLI

```bash
gh auth login        # GitHub.com ▸ HTTPS ▸ Login with a web browser
gh repo set-default  # Choose your own fork
```

> In Codespaces, the `GITHUB_TOKEN` environment variable may not have enough permissions. If `gh variable set` returns `403`,
> run `unset GITHUB_TOKEN && gh auth login` and try again.

## ✅ Checkpoint

- [ ] `az account show` shows your subscription
- [ ] `gh auth status` shows you are logged in
- [ ] Actions is enabled on your fork

Next: [Module 1. Why Secretless?](01-concepts.md)
