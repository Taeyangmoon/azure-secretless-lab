# 모듈 5. 검증 & 장애 체험 (20분)

보안은 **"깨져 봐야 이해"** 됩니다. 일부러 설정을 틀어서 어떤 에러가 나는지, 왜 나는지 확인합니다.
각 실습 후에는 **반드시 원상복구** 하세요.

---

## 실습 A. 시크릿이 정말 없는지 감사하기 (5분)

```bash
# 1) GitHub 에 저장된 시크릿
gh secret list

# 2) Container App 에 저장된 시크릿
az containerapp secret list -g rg-secretless-lab -n secretless-app

# 3) 환경변수 이름 확인 (값에 비밀이 없는지)
az containerapp show -g rg-secretless-lab -n secretless-app \
  --query "properties.template.containers[0].env[].{name:name, value:value}" -o table

# 4) ACR admin
az acr show -n <acrName> --query adminUserEnabled

# 5) 저장소 안에 비밀번호가 있는지
git grep -inE "password|secret|connection ?string" -- . ':!docs' ':!README.md' ':!app/package-lock.json'
```

| 항목 | 기대 결과 |
|---|---|
| GitHub Secrets | 비어 있음 |
| Container App Secrets | 비어 있음 |
| 환경변수 | `AZURE_CLIENT_ID`, `KEY_VAULT_URL`, `SECRET_NAME`, `APP_VERSION` 뿐 |
| ACR admin | `false` |

> 5번에서 나오는 `secret` 은 Key Vault 시크릿 *이름/주석*일 뿐 값이 아닙니다.

---

## 실습 B. subject 불일치 — 다른 환경에서는 로그인 불가 (5분)

> **가설:** Federated Credential 은 `environment:prod` 만 신뢰한다. 다른 환경에서 실행한 job 은 로그인에 실패해야 한다.

1. `.github/workflows/deploy.yml` 의 `environment: prod` 를 `environment: staging` 으로 변경 후 push
2. Actions 에서 `Azure login (OIDC)` 단계가 **실패** 하는지 확인

기대 에러:

```
AADSTS700213: No matching federated identity record found for presented assertion
subject 'repo:<owner>/<repo>:environment:staging'.
Check your federated identity credential Subject, Audience and Issuer against the presented assertion.
```

3. 에러 메시지의 `subject` 값과 Azure 에 등록한 subject 를 비교해 보세요.
4. **복구:** `environment: prod` 로 되돌리고 push.

> 💡 **배운 점:** Azure는 "이 저장소 사람"이 아니라 "**이 저장소의 이 환경에서 실행된 job**"만 신뢰합니다. 포크한 다른 사람의 저장소는 subject 가 달라서 통과할 수 없습니다.

---

## 실습 C. `id-token: write` 권한 제거 (3분)

1. `deploy.yml` 상단의 `id-token: write` 줄을 삭제하고 push
2. 기대 에러:

```
Error: Unable to get ACTIONS_ID_TOKEN_REQUEST_URL env variable
```

3. **복구:** 다시 추가.

> 💡 OIDC 토큰은 워크플로가 **명시적으로 요청한 경우에만** 발급됩니다. 기본값은 발급 불가 = 안전한 기본값.

---

## 실습 D. 앱의 권한 빼앗기 — RBAC 가 동작하는지 확인 (5분)

앱의 Key Vault 접근 권한을 제거합니다.

```bash
APP_URL=$(az deployment group show -g rg-secretless-lab -n main --query properties.outputs.appUrl.value -o tsv)
KV=$(az deployment group show -g rg-secretless-lab -n main --query properties.outputs.keyVaultName.value -o tsv)
APP_PID=$(az identity show -g rg-secretless-lab -n secretless-id-app --query principalId -o tsv)
KV_ID=$(az keyvault show -n $KV --query id -o tsv)

az role assignment delete --assignee $APP_PID --role "Key Vault Secrets User" --scope $KV_ID
```

> 역할 변경은 반영까지 **1~2분** 걸릴 수 있습니다.

```bash
curl -s $APP_URL/api/secret | python3 -m json.tool
```

기대 결과: HTTP 502, `detail` 에 `Forbidden` / `does not have secrets get permission` 포함.

**복구:**

```bash
az role assignment create --assignee-object-id $APP_PID --assignee-principal-type ServicePrincipal \
  --role "Key Vault Secrets User" --scope $KV_ID
```

1~2분 뒤 다시 `/api/secret` 이 성공하는지 확인합니다.

> 💡 **배운 점:** 접근 제어가 앱 코드/설정이 아닌 **Azure RBAC** 에 있습니다. 권한을 회수하면 재배포 없이 즉시 차단됩니다. 키를 교체(rotation)할 일도 없습니다.

---

## 실습 E. Entra 로그에서 로그인 흔적 보기 (2분)

Azure Portal ▸ **Microsoft Entra ID ▸ Monitoring ▸ Sign-in logs ▸ Service principal sign-ins / Managed identity sign-ins**

- `secretless-id-github` 로 로그인한 기록 (GitHub Actions)
- 인증 방법이 *Federated identity credential* 로 표시됨

로그에 누가, 언제, 어디서 로그인했는지 남으므로 공유 시크릿보다 **감사(audit)** 가 쉽습니다.

---

## 🏆 도전 과제 (시간이 남는다면)

1. **PR 용 별도 신원**: `ci.yml` 에서 `pull_request` 로 Azure 읽기 전용(`Reader`) 작업을 하고 싶다면, subject `repo:<owner>/<repo>:pull_request` 의 Federated Credential 과 `Reader` 신원을 별도로 만들어 보세요. (Contributor 를 PR 에 주면 안 되는 이유는?)
2. **Storage 추가**: Bicep 에 Storage Account 를 추가하고 `allowSharedKeyAccess: false` 로 설정한 뒤, 앱에 `Storage Blob Data Reader` 를 부여해 `@azure/storage-blob` + `DefaultAzureCredential` 로 Blob 을 읽어 보세요.
3. **권한 더 줄이기**: 배포 신원의 `Contributor` 를 `AcrPush` + `Container Apps Contributor` 등으로 쪼개 보세요.
4. **승인 게이트**: `prod` 환경에 Required reviewers 를 추가하고 배포 흐름을 확인하세요.

다음: [모듈 6. 정리](06-cleanup.md)
