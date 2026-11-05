# 모듈 0. 사전 준비 (10분)

## 필요한 것

| 항목 | 설명 |
|---|---|
| Azure 구독 | 리소스 그룹을 만들고 **역할 할당(Role Assignment)** 을 할 수 있는 권한 (`Owner` 또는 `Contributor` + `User Access Administrator`) |
| GitHub 계정 | 저장소를 Fork하고 Actions를 사용할 수 있는 계정 |
| 실습 환경 | **GitHub Codespaces (권장)** 또는 로컬에 `az`, `gh`, `node 22` 설치 |

> 💡 Azure Entra ID 앱 등록 권한은 **필요 없습니다.** 이 실습은 Managed Identity를 사용하기 때문에 구독 RBAC 권한만 있으면 됩니다.

## 1. 저장소 Fork

1. 원본 저장소 우측 상단 **Fork** ▸ **Create fork**
2. Fork된 저장소 **Settings ▸ Actions ▸ General** 에서 Actions가 활성화되어 있는지 확인합니다. (Fork는 기본적으로 워크플로가 꺼져 있을 수 있습니다 — Actions 탭에서 `I understand my workflows, go ahead and enable them` 클릭)

## 2. Codespace 열기

**Code ▸ Codespaces ▸ Create codespace on main**

터미널에서 도구를 확인합니다.

```bash
az version
gh --version
node -v
```

## 3. Azure 로그인

```bash
az login --use-device-code
az account show --query '{name:name, id:id, tenant:tenantId}' -o table
```

여러 구독이 있다면 실습에 사용할 구독을 선택합니다.

```bash
az account set --subscription "<구독 이름 또는 ID>"
```

필요한 리소스 공급자를 등록합니다. (처음 한 번만, 1~2분)

```bash
for ns in Microsoft.App Microsoft.ContainerRegistry Microsoft.KeyVault Microsoft.OperationalInsights Microsoft.ManagedIdentity; do
  az provider register --namespace $ns
done
```

## 4. GitHub CLI 로그인

```bash
gh auth login        # GitHub.com ▸ HTTPS ▸ Login with a web browser
gh repo set-default  # Fork한 본인의 저장소 선택
```

> Codespaces에서는 `GITHUB_TOKEN` 환경변수 때문에 권한이 부족할 수 있습니다. `gh variable set` 단계에서 `403` 이 나면
> `unset GITHUB_TOKEN && gh auth login` 후 다시 시도하세요.

## ✅ 체크포인트

- [ ] `az account show` 에 내 구독이 표시된다
- [ ] `gh auth status` 가 로그인 상태이다
- [ ] 본인 Fork 저장소의 Actions가 활성화되어 있다

다음: [모듈 1. 왜 Secretless 인가?](01-concepts.md)
