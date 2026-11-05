#!/usr/bin/env bash
# Lab 1: Create the resource group and deploy the infrastructure (Bicep)
set -euo pipefail

RG="${RG:-rg-secretless-lab}"
LOCATION="${LOCATION:-koreacentral}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "▶ Subscription: $(az account show --query '[name,id]' -o tsv | tr '\t' ' / ')"
echo "▶ Creating resource group: $RG ($LOCATION)"
az group create --name "$RG" --location "$LOCATION" --output none

echo "▶ Deploying Bicep... (about 3-5 minutes)"
az deployment group create \
  --name main \
  --resource-group "$RG" \
  --template-file "$REPO_ROOT/infra/main.bicep" \
  --query 'properties.outputs.{acr:acrName.value, app:containerAppName.value, url:appUrl.value, keyVault:keyVaultName.value}' \
  --output table

echo "✅ Infrastructure deployed"
