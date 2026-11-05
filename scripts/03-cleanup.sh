#!/usr/bin/env bash
# Lab 6: Clean up the lab resources
set -euo pipefail

RG="${RG:-rg-secretless-lab}"
GITHUB_REPO="${1:-}"

echo "▶ Deleting resource group: $RG (runs in the background)"
az group delete --name "$RG" --yes --no-wait

# To avoid name conflicts from soft-deleted Key Vaults, purge them with:
#   az keyvault list-deleted --query "[].name" -o tsv | xargs -I{} az keyvault purge --name {}

if [[ -n "$GITHUB_REPO" ]] && command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  echo "▶ Deleting GitHub variables/environment: $GITHUB_REPO"
  for v in AZURE_CLIENT_ID AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID AZURE_RESOURCE_GROUP ACR_NAME CONTAINER_APP_NAME; do
    gh variable delete "$v" --repo "$GITHUB_REPO" 2>/dev/null || true
  done
  gh api -X DELETE "repos/${GITHUB_REPO}/environments/prod" --silent 2>/dev/null || true
fi

echo "✅ Cleanup requested. In a few minutes, check that 'az group exists -n $RG' returns false."
