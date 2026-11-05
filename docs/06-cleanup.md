# 모듈 6. 정리 (5분)

비용이 계속 발생하지 않도록 실습 리소스를 삭제합니다.

```bash
./scripts/03-cleanup.sh <owner>/<repo>
```

스크립트가 하는 일:

1. 리소스 그룹 `rg-secretless-lab` 삭제 (ACR, Key Vault, Container Apps, Managed Identity, Federated Credential **모두 포함**)
2. GitHub 저장소 변수 6개와 `prod` 환경 삭제

삭제 확인 (수 분 소요):

```bash
az group exists -n rg-secretless-lab   # false 가 되면 완료
```

> 🧹 **Key Vault Soft-delete:** 삭제된 Key Vault 는 7일간 소프트 삭제 상태로 남습니다. 같은 이름 재사용 등으로 문제가 되면
> `az keyvault purge --name <이름>` 으로 영구 삭제할 수 있습니다. (이 실습은 이름에 랜덤 접미사를 붙여 충돌하지 않습니다.)

## 🎓 마무리 — 오늘 배운 것

| 질문 | 답 |
|---|---|
| GitHub Actions는 비밀번호 없이 어떻게 Azure에 로그인하나? | OIDC 토큰을 Entra ID가 Federated Credential(issuer/subject/audience)과 대조해 검증 |
| `client-id`, `tenant-id` 를 Variables 에 둬도 안전한 이유? | 식별자일 뿐 자격 증명이 아님. 토큰은 GitHub 가 서명해 발급 |
| 앱은 Key Vault 에 어떻게 접근하나? | Managed Identity + RBAC, 코드는 `DefaultAzureCredential` |
| 왜 배포 신원과 앱 신원을 분리하나? | 한쪽이 침해돼도 피해 범위를 제한 (최소 권한) |
| Secretless 의 가장 큰 이점은? | 유출·만료·교체(rotation)의 부담 자체가 사라짐 |

## 📖 더 알아보기

- [GitHub: Azure에서 OpenID Connect 구성](https://docs.github.com/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-azure)
- [Microsoft Learn: Workload identity federation](https://learn.microsoft.com/entra/workload-id/workload-identity-federation)
- [Microsoft Learn: Managed identities for Azure resources](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/overview)
- [Azure Container Apps: Managed Identity](https://learn.microsoft.com/azure/container-apps/managed-identity)
- [Azure SDK: DefaultAzureCredential](https://learn.microsoft.com/azure/developer/intro/passwordless-overview)

수고하셨습니다! 🎉
