# 트러블슈팅

| 증상 | 원인 | 해결 |
|---|---|---|
| `AuthorizationFailed ... roleAssignments/write` (모듈 2/3) | 구독에서 역할 할당 권한 없음 | `Owner` 또는 `User Access Administrator` 권한 요청 |
| `MissingSubscriptionRegistration` | 리소스 공급자 미등록 | 모듈 0의 `az provider register` 실행 후 1~2분 대기 |
| Bicep 배포가 일시적 오류로 실패 | 일시적 ARM 오류 | `./scripts/01-deploy-infra.sh` 재실행 (멱등) |
| `gh variable set` → `403 / Resource not accessible` | Codespaces 의 `GITHUB_TOKEN` 권한 부족 | `unset GITHUB_TOKEN && gh auth login` 후 `02-setup-oidc.sh` 재실행 |
| `02-setup-oidc.sh` 재실행 시 이미 존재 오류 | 이전 실행 잔재 | Federated credential: `az identity federated-credential delete -n github-prod --identity-name secretless-id-github -g rg-secretless-lab -y` 후 재실행 |
| `AADSTS700213: No matching federated identity record` | subject 불일치 (저장소 이름 오타/대소문자, 환경 이름 불일치) | 로그의 subject 와 Azure 의 Federated credential subject 를 비교, 수정 |
| `AADSTS700016: Application with identifier ... not found` | `AZURE_CLIENT_ID` / `AZURE_TENANT_ID` 값 오류 | `gh variable list` 와 `az identity show -n secretless-id-github -g ... --query clientId` 비교 |
| `Unable to get ACTIONS_ID_TOKEN_REQUEST_URL` | `permissions: id-token: write` 누락 | 워크플로에 권한 추가 |
| `Login failed ... No subscriptions found` | Contributor 역할 전파 지연 | 1~2분 후 재실행 (Re-run jobs) |
| `deploy` 가 `Waiting` 상태로 멈춤 | `prod` 환경에 Required reviewers 설정됨 | Actions 화면에서 **Review deployments** 승인 |
| Fork 에서 워크플로가 실행되지 않음 | Fork 는 Actions 비활성 기본값 | Actions 탭에서 활성화 |
| Smoke test 가 계속 실패 | 새 리비전 기동 지연 / 포트 불일치 | `az containerapp logs show -g rg-secretless-lab -n secretless-app --tail 50`, `az containerapp revision list ... -o table` |
| `/api/secret` 이 502 `Forbidden` | 앱 신원에 역할 없음 / 전파 지연 | 포털 Key Vault ▸ IAM 에서 `Key Vault Secrets User` 확인, 2분 후 재시도 |
| `/api/secret` 이 502 `ManagedIdentityCredential ... unavailable` | `AZURE_CLIENT_ID` 미설정 | `az containerapp show ... --query "properties.template.containers[0].env"` 확인 |
| 컨테이너가 `ImagePullBackOff` / `UNAUTHORIZED` | AcrPull 역할 전파 지연 또는 누락 | ACR ▸ IAM 에서 `AcrPull` 확인 후 새 리비전 생성 |
| Key Vault 이름 충돌 (`VaultAlreadyExists`) | 소프트 삭제된 동일 이름 | `az keyvault purge --name <이름>` |

## 유용한 진단 명령

```bash
# 로그
az containerapp logs show -g rg-secretless-lab -n secretless-app --tail 50

# 리비전 상태
az containerapp revision list -g rg-secretless-lab -n secretless-app -o table

# 배포 신원의 Federated Credential
az identity federated-credential list --identity-name secretless-id-github -g rg-secretless-lab -o table

# 배포 신원에 부여된 역할
az role assignment list --assignee $(az identity show -n secretless-id-github -g rg-secretless-lab --query principalId -o tsv) \
  --all -o table
```

## 참고: 인프라를 다시 배포하면?

`01-deploy-infra.sh` 를 다시 실행하면 Container App 이 **초기 placeholder 이미지**로 되돌아갑니다.
그 후 `deploy.yml` 을 다시 실행(Actions ▸ Run workflow)하면 복구됩니다.
