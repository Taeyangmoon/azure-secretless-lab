# 모듈 2. 인프라 배포 (15분)

Bicep으로 실습에 필요한 Azure 리소스를 만듭니다. **이 단계에서 만드는 시크릿은 0개**입니다.

## 1. 먼저 코드 읽기 (5분)

[`infra/main.bicep`](../infra/main.bicep) 을 열고 아래 포인트를 찾아보세요.

| 찾아보기 | 위치 | 의미 |
|---|---|---|
| `adminUserEnabled: false` | ACR | 레지스트리 사용자/비밀번호 비활성화 |
| `enableRbacAuthorization: true` | Key Vault | 액세스 정책 대신 Azure RBAC |
| `Microsoft.ManagedIdentity/userAssignedIdentities` | `appIdentity` | 앱이 쓸 신원 |
| `acrPullAssignment`, `kvSecretsUserAssignment` | 역할 할당 | 앱 신원에 **필요한 권한만** 부여 |
| `registries: [{ identity: ... }]` | Container App | ACR Pull도 Managed Identity로 |
| `env: [...]` | Container App | `AZURE_CLIENT_ID`, `KEY_VAULT_URL` — 모두 **비밀이 아닌 식별자/주소** |

> ❓ **질문:** 환경변수에 `AZURE_CLIENT_ID` 가 있는데, 이것도 시크릿 아닌가요?
> 아닙니다. 어떤 신원을 쓸지 **가리키는 ID** 일 뿐, 토큰은 Azure가 플랫폼 내부에서만 발급합니다.

## 2. 배포하기 (5분)

```bash
./scripts/01-deploy-infra.sh
```

환경변수로 이름/리전을 바꿀 수 있습니다.

```bash
RG=rg-secretless-<내이름> LOCATION=koreacentral ./scripts/01-deploy-infra.sh
```

> ⚠️ 리소스 그룹 이름을 바꿨다면 이후 모든 스크립트 실행 시 같은 `RG=` 를 지정하세요.

배포가 끝나면 출력되는 `url` 을 확인합니다. 지금은 아직 **placeholder 이미지**(Microsoft 샘플)가 떠 있습니다.

```bash
az deployment group show -g rg-secretless-lab -n main --query properties.outputs.appUrl.value -o tsv
```

## 3. 포털에서 확인하기 (5분)

[Azure Portal](https://portal.azure.com) ▸ 리소스 그룹 `rg-secretless-lab`

1. **Container Registry ▸ Settings ▸ Access keys** → *Admin user* 가 **Disabled** 인지 확인
2. **Key Vault ▸ Access control (IAM) ▸ Role assignments** → `secretless-id-app` 에 `Key Vault Secrets User` 가 있는지 확인
3. **Container App ▸ Settings ▸ Identity** → *User assigned* 탭에 `secretless-id-app` 이 있는지 확인
4. **Container App ▸ Settings ▸ Secrets** → **비어 있음** 을 확인 🎉

CLI로도 확인할 수 있습니다.

```bash
az containerapp secret list -g rg-secretless-lab -n secretless-app -o table
az acr show -n <acrName> --query adminUserEnabled
```

## ✅ 체크포인트

- [ ] 배포가 성공했고 `rg-secretless-lab` 에 리소스 7~8개가 보인다
- [ ] ACR admin user = `false`
- [ ] Container App 의 Secrets 목록이 비어 있다

다음: [모듈 3. GitHub ↔ Azure OIDC 연결](03-setup-oidc.md)
