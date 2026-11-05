#!/usr/bin/env bash
# Lab 6: 실습 리소스 정리
set -euo pipefail

RG="${RG:-rg-secretless-lab}"
GITHUB_REPO="${1:-}"

echo "▶ 리소스 그룹 삭제: $RG (백그라운드로 진행)"
az group delete --name "$RG" --yes --no-wait

# 소프트 삭제된 Key Vault 가 남아 있어도 이름 충돌이 없도록 purge 하려면 아래를 사용하세요.
#   az keyvault list-deleted --query "[].name" -o tsv | xargs -I{} az keyvault purge --name {}

if [[ -n "$GITHUB_REPO" ]] && command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  echo "▶ GitHub 변수/환경 삭제: $GITHUB_REPO"
  for v in AZURE_CLIENT_ID AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID AZURE_RESOURCE_GROUP ACR_NAME CONTAINER_APP_NAME; do
    gh variable delete "$v" --repo "$GITHUB_REPO" 2>/dev/null || true
  done
  gh api -X DELETE "repos/${GITHUB_REPO}/environments/prod" --silent 2>/dev/null || true
fi

echo "✅ 정리 요청 완료. 몇 분 후 'az group exists -n $RG' 가 false 인지 확인하세요."
