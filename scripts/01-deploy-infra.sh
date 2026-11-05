#!/usr/bin/env bash
# Lab 1: 리소스 그룹 + 인프라(Bicep) 배포
set -euo pipefail

RG="${RG:-rg-secretless-lab}"
LOCATION="${LOCATION:-koreacentral}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "▶ 구독: $(az account show --query '[name,id]' -o tsv | tr '\t' ' / ')"
echo "▶ 리소스 그룹 생성: $RG ($LOCATION)"
az group create --name "$RG" --location "$LOCATION" --output none

echo "▶ Bicep 배포 중... (약 3~5분)"
az deployment group create \
  --name main \
  --resource-group "$RG" \
  --template-file "$REPO_ROOT/infra/main.bicep" \
  --query 'properties.outputs.{acr:acrName.value, app:containerAppName.value, url:appUrl.value, keyVault:keyVaultName.value}' \
  --output table

echo "✅ 인프라 배포 완료"
