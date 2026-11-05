# 모듈 3. GitHub ↔ Azure OIDC 연결 (15분)

이 모듈이 이번 실습의 핵심입니다. **"어떤 GitHub 워크플로를 Azure가 신뢰할지"** 를 설정합니다.

## 1. 한 번에 설정하기

본인의 Fork 저장소 이름(`<owner>/<repo>`)을 넣어 실행합니다.

```bash
./scripts/02-setup-oidc.sh <owner>/<repo>
# 예) ./scripts/02-setup-oidc.sh octocat/azure-secretless-lab
```

스크립트가 하는 일을 하나씩 살펴봅니다.

### ① 배포용 Managed Identity 생성

```bash
az identity create --name secretless-id-github --resource-group rg-secretless-lab
```

> 💡 App Registration(서비스 주체) 대신 User-assigned Managed Identity를 사용해도 Federated Credential을 붙일 수 있습니다.
> Entra ID 앱 등록 권한이 없어도 되어 실습 환경에서 가장 안정적입니다.

### ② Federated Credential 등록 ⭐

```bash
az identity federated-credential create \
  --name github-prod \
  --identity-name secretless-id-github \
  --resource-group rg-secretless-lab \
  --issuer https://token.actions.githubusercontent.com \
  --subject repo:<owner>/<repo>:environment:prod \
  --audiences api://AzureADTokenExchange
```

이 한 줄이 의미하는 것:

> "GitHub(`issuer`)이 서명한 토큰 중, **`<owner>/<repo>` 저장소의 `prod` 환경** 에서 실행된 job(`subject`)이 제시하는 토큰이라면, 이 신원(`secretless-id-github`)으로 인정한다."

### ③ 역할 할당 (최소 권한)

```bash
az role assignment create --role Contributor --scope <리소스 그룹 ID> \
  --assignee-object-id <principalId> --assignee-principal-type ServicePrincipal
```

구독 전체가 아닌 **리소스 그룹 범위**로만 권한을 줍니다. 파이프라인이 침해돼도 피해 범위가 이 RG로 제한됩니다.

### ④ GitHub 변수 등록

`gh variable set` 으로 아래 **변수(Variables)** 를 등록하고, `prod` 환경을 만듭니다.

| 이름 | 용도 |
|---|---|
| `AZURE_CLIENT_ID` | 배포 신원의 Client ID |
| `AZURE_TENANT_ID` | Entra 테넌트 ID |
| `AZURE_SUBSCRIPTION_ID` | 구독 ID |
| `AZURE_RESOURCE_GROUP` | 리소스 그룹 이름 |
| `ACR_NAME` | 레지스트리 이름 |
| `CONTAINER_APP_NAME` | 컨테이너 앱 이름 |

## 2. 결과 확인

**GitHub 쪽**

```bash
gh variable list      # 6개 변수가 보여야 합니다
gh secret list        # ⭐ 비어 있어야 합니다!
```

또는 저장소 **Settings ▸ Secrets and variables ▸ Actions** 에서 `Secrets` 탭이 **비어 있음** 을 확인하세요.

**Azure 쪽**

```bash
az identity federated-credential list \
  --identity-name secretless-id-github -g rg-secretless-lab -o table
```

포털: **Managed Identity `secretless-id-github` ▸ Settings ▸ Federated credentials**

## 3. (선택) 환경 보호 규칙 추가

`subject` 에 `environment:prod` 를 썼기 때문에, GitHub 환경 보호 규칙과 결합할 수 있습니다.

**Settings ▸ Environments ▸ prod ▸ Required reviewers** 에 본인(또는 팀원)을 추가하면 배포 전에 **수동 승인** 이 필요합니다.
승인 없이는 OIDC 토큰 자체가 발급되지 않습니다.

## ✅ 체크포인트

- [ ] `gh secret list` 결과가 비어 있다
- [ ] `gh variable list` 에 6개 변수가 있다
- [ ] Azure 포털에서 Federated credential `github-prod` 의 subject 가 본인 저장소와 일치한다
- [ ] 저장소의 Settings ▸ Environments 에 `prod` 가 있다

> ⚠️ `gh` 실행이 실패해 스크립트가 값을 출력만 했다면, 출력된 값을 **Variables** 탭에 직접 추가하고 `prod` 환경을 수동으로 만드세요.

다음: [모듈 4. CI/CD 파이프라인 실행](04-pipeline.md)
