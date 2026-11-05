# 모듈 4. CI/CD 파이프라인 실행 (15분)

## 1. 워크플로 읽기 (5분)

### `ci.yml` — 검증용 (Azure 접근 없음)

```yaml
permissions:
  contents: read      # 읽기 전용. Azure 와 통신하지 않는다.
```

PR/브랜치 push 때 테스트와 Docker 빌드만 수행합니다. **시크릿도, 클라우드 권한도 없습니다.**

### `deploy.yml` — 배포용 (OIDC)

| 라인 | 의미 |
|---|---|
| `permissions: id-token: write` | GitHub에게 OIDC 토큰 발급을 요청할 권한. **이게 없으면 로그인 실패** |
| `environment: prod` | 토큰의 subject 가 `...:environment:prod` 가 됨 → Federated Credential 과 일치해야 함 |
| `azure/login@v2` + `client-id / tenant-id / subscription-id` | **`client-secret` 입력이 없다!** 모두 `vars.` (변수) |
| `az acr build` | 빌드를 ACR 에서 수행 → 러너에 Docker 로그인/레지스트리 비밀번호 불필요 |
| `az containerapp update --image` | 새 리비전 배포. 앱은 Managed Identity 로 ACR 에서 Pull |

```yaml
- uses: azure/login@v2
  with:
    client-id: ${{ vars.AZURE_CLIENT_ID }}
    tenant-id: ${{ vars.AZURE_TENANT_ID }}
    subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
    # client-secret 없음 ⭐
```

## 2. 배포 실행 (5분)

main 브랜치에 앱 변경을 push 하면 자동으로 실행됩니다. 먼저 눈에 띄는 변경을 하나 만들어 봅시다.

```bash
# app/src/app.js 의 <h1> 문구를 본인 이름이 들어가게 수정
sed -i 's|Azure Secretless CI/CD Lab|Azure Secretless CI/CD Lab - <내 이름>|' app/src/app.js

git add -A
git commit -m "feat: personalize landing page"
git push origin main
```

또는 **Actions ▸ Deploy to Azure ▸ Run workflow** 로 수동 실행할 수 있습니다.

### 진행 관찰

저장소 **Actions** 탭에서 실행 중인 워크플로를 엽니다.

1. `test` job 이 통과하면
2. `deploy` job 이 시작됩니다. (`prod` 환경에 승인 규칙을 걸었다면 **Review deployments** 를 승인)
3. **Azure login (OIDC)** 단계 로그를 펼쳐 보세요.

```
Federated token details:
 issuer - https://token.actions.githubusercontent.com
 subjectClaim - sub
 audience - api://AzureADTokenExchange
 ...
Login successful.
```

> 🔍 로그 어디에도 비밀번호가 없습니다. 이 단계가 **GitHub 토큰 ↔ Entra 토큰 교환** 입니다.

4. **Build & push image** → **Deploy to Container Apps** → **Smoke test** 순으로 성공합니다.

## 3. 결과 확인 (5분)

워크플로 **Summary** 에 앱 URL(`🚀 배포 완료`)이 표시됩니다. 터미널에서도 확인할 수 있습니다.

```bash
APP_URL=$(az deployment group show -g rg-secretless-lab -n main --query properties.outputs.appUrl.value -o tsv)
curl -s $APP_URL/api/info | python3 -m json.tool
curl -s $APP_URL/api/secret | python3 -m json.tool
```

기대 결과:

```json
{
  "version": "a1b2c3d",
  "authMode": "user-assigned managed identity",
  "secretLikeEnvVars": [],
  "secretless": true
}
{
  "name": "demo-message",
  "value": "Hello from Key Vault! 이 값은 코드/환경변수/GitHub Secrets 어디에도 없습니다.",
  "source": "Azure Key Vault (Managed Identity)"
}
```

브라우저에서 `APP_URL` 을 열고 버튼도 눌러보세요.

## ✅ 체크포인트

- [ ] `deploy.yml` 실행이 성공(초록색)했다
- [ ] `Azure login (OIDC)` 로그에서 `Login successful` 을 확인했다
- [ ] `/api/info` 의 `version` 이 방금 커밋 SHA 앞 7자리와 같다
- [ ] `/api/secret` 이 Key Vault 값을 반환한다

> 🤔 **생각해 보기:** 앱은 Key Vault 값을 읽었는데, 코드와 환경변수에는 어떤 자격 증명도 없습니다. 이 요청을 인증한 건 누구일까요?
> → 앱이 `DefaultAzureCredential` 로 Managed Identity 토큰을 받아 Key Vault에 제시했고, Key Vault 는 RBAC(`Key Vault Secrets User`)를 확인했습니다.

다음: [모듈 5. 검증 & 장애 체험](05-verify-and-break.md)
