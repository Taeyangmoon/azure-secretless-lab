#!/usr/bin/env bash
# Lab 2: Set up OIDC (Workload Identity Federation) between GitHub Actions and Azure
#  1) Create a Managed Identity for deployments
#  2) Register a Federated Credential (trust only workflows running in this repo's 'prod' environment)
#  3) Grant Contributor on the resource group
#  4) Register GitHub repository Variables  <- NOT Secrets!
set -euo pipefail

GITHUB_REPO="${1:?Usage: ./scripts/02-setup-oidc.sh <github-owner>/<repo>}"
RG="${RG:-rg-secretless-lab}"
ENV_NAME="${ENV_NAME:-prod}"
IDENTITY_NAME="${IDENTITY_NAME:-secretless-id-github}"
LOCATION="$(az group show -n "$RG" --query location -o tsv)"

echo "▶ Creating deployment Managed Identity: $IDENTITY_NAME"
az identity create --name "$IDENTITY_NAME" --resource-group "$RG" --location "$LOCATION" --output none

CLIENT_ID="$(az identity show -n "$IDENTITY_NAME" -g "$RG" --query clientId -o tsv)"
PRINCIPAL_ID="$(az identity show -n "$IDENTITY_NAME" -g "$RG" --query principalId -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"
SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
RG_ID="$(az group show -n "$RG" --query id -o tsv)"

SUBJECT="repo:${GITHUB_REPO}:environment:${ENV_NAME}"
echo "▶ Registering Federated Credential"
echo "   issuer : https://token.actions.githubusercontent.com"
echo "   subject: $SUBJECT"
az identity federated-credential create \
  --name "github-${ENV_NAME}" \
  --identity-name "$IDENTITY_NAME" \
  --resource-group "$RG" \
  --issuer "https://token.actions.githubusercontent.com" \
  --subject "$SUBJECT" \
  --audiences "api://AzureADTokenExchange" \
  --output none

echo "▶ Assigning role: Contributor @ $RG"
az role assignment create \
  --assignee-object-id "$PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role Contributor \
  --scope "$RG_ID" \
  --output none

OUT="$(az deployment group show -g "$RG" -n main --query properties.outputs -o json)"
ACR_NAME="$(echo "$OUT" | python3 -c 'import json,sys; print(json.load(sys.stdin)["acrName"]["value"])')"
APP_NAME="$(echo "$OUT" | python3 -c 'import json,sys; print(json.load(sys.stdin)["containerAppName"]["value"])')"

echo "▶ Configuring the GitHub repository"
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  gh api -X PUT "repos/${GITHUB_REPO}/environments/${ENV_NAME}" --silent
  for kv in "AZURE_CLIENT_ID=$CLIENT_ID" "AZURE_TENANT_ID=$TENANT_ID" "AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID" \
            "AZURE_RESOURCE_GROUP=$RG" "ACR_NAME=$ACR_NAME" "CONTAINER_APP_NAME=$APP_NAME"; do
    gh variable set "${kv%%=*}" --body "${kv#*=}" --repo "$GITHUB_REPO"
  done
  echo "✅ Registered the environment ($ENV_NAME) and variables with the gh CLI."
else
  echo "⚠️  gh CLI is not logged in, so manual setup is required. Add these values under"
  echo "   Settings > Secrets and variables > Actions > Variables:"
  printf '   AZURE_CLIENT_ID=%s\n   AZURE_TENANT_ID=%s\n   AZURE_SUBSCRIPTION_ID=%s\n   AZURE_RESOURCE_GROUP=%s\n   ACR_NAME=%s\n   CONTAINER_APP_NAME=%s\n' \
    "$CLIENT_ID" "$TENANT_ID" "$SUBSCRIPTION_ID" "$RG" "$ACR_NAME" "$APP_NAME"
  echo "   Then create the '$ENV_NAME' environment under Settings > Environments."
fi
