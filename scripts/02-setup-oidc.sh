#!/usr/bin/env bash
# Lab 2: GitHub Actions <-> Azure OIDC(Workload Identity Federation) 설정
#  1) 배포용 Managed Identity 생성
#  2) Federated Credential 등록 (이 저장소의 'prod' 환경에서 실행된 워크플로만 신뢰)
#  3) 리소스 그룹에 Contributor 역할 부여
#  4) GitHub 저장소 변수(Variables) 등록  ← Secrets 가 아닙니다!
set -euo pipefail

GITHUB_REPO="${1:?사용법: ./scripts/02-setup-oidc.sh <github-owner>/<repo>}"
RG="${RG:-rg-secretless-lab}"
ENV_NAME="${ENV_NAME:-prod}"
IDENTITY_NAME="${IDENTITY_NAME:-secretless-id-github}"
LOCATION="$(az group show -n "$RG" --query location -o tsv)"

echo "▶ 배포용 Managed Identity 생성: $IDENTITY_NAME"
az identity create --name "$IDENTITY_NAME" --resource-group "$RG" --location "$LOCATION" --output none

CLIENT_ID="$(az identity show -n "$IDENTITY_NAME" -g "$RG" --query clientId -o tsv)"
PRINCIPAL_ID="$(az identity show -n "$IDENTITY_NAME" -g "$RG" --query principalId -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"
SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
RG_ID="$(az group show -n "$RG" --query id -o tsv)"

SUBJECT="repo:${GITHUB_REPO}:environment:${ENV_NAME}"
echo "▶ Federated Credential 등록"
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

echo "▶ 역할 할당: Contributor @ $RG"
az role assignment create \
  --assignee-object-id "$PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role Contributor \
  --scope "$RG_ID" \
  --output none

OUT="$(az deployment group show -g "$RG" -n main --query properties.outputs -o json)"
ACR_NAME="$(echo "$OUT" | python3 -c 'import json,sys; print(json.load(sys.stdin)["acrName"]["value"])')"
APP_NAME="$(echo "$OUT" | python3 -c 'import json,sys; print(json.load(sys.stdin)["containerAppName"]["value"])')"

echo "▶ GitHub 저장소 설정"
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  gh api -X PUT "repos/${GITHUB_REPO}/environments/${ENV_NAME}" --silent
  for kv in "AZURE_CLIENT_ID=$CLIENT_ID" "AZURE_TENANT_ID=$TENANT_ID" "AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID" \
            "AZURE_RESOURCE_GROUP=$RG" "ACR_NAME=$ACR_NAME" "CONTAINER_APP_NAME=$APP_NAME"; do
    gh variable set "${kv%%=*}" --body "${kv#*=}" --repo "$GITHUB_REPO"
  done
  echo "✅ gh CLI 로 환경($ENV_NAME)과 변수를 등록했습니다."
else
  echo "⚠️  gh CLI 로그인이 안 되어 있어 수동 등록이 필요합니다. 아래 값을"
  echo "   Settings > Secrets and variables > Actions > Variables 탭에 추가하세요."
  printf '   AZURE_CLIENT_ID=%s\n   AZURE_TENANT_ID=%s\n   AZURE_SUBSCRIPTION_ID=%s\n   AZURE_RESOURCE_GROUP=%s\n   ACR_NAME=%s\n   CONTAINER_APP_NAME=%s\n' \
    "$CLIENT_ID" "$TENANT_ID" "$SUBSCRIPTION_ID" "$RG" "$ACR_NAME" "$APP_NAME"
  echo "   그리고 Settings > Environments 에서 '$ENV_NAME' 환경을 만드세요."
fi
