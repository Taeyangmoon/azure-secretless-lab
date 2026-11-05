# 진행자 가이드

## 사전 점검 (행사 1주 전)

- [ ] 참석자 전원이 **구독에서 역할 할당이 가능한지**(Owner 또는 UAA) 확인 — 가장 흔한 실패 원인
- [ ] 리소스 공급자 사전 등록: `Microsoft.App`, `Microsoft.ContainerRegistry`, `Microsoft.KeyVault`, `Microsoft.OperationalInsights`, `Microsoft.ManagedIdentity`
- [ ] 리전별 Container Apps 쿼터 확인 (기본 `koreacentral`). 필요하면 `LOCATION=` 변경 안내
- [ ] 참석자 GitHub 계정에서 Fork 한 저장소의 Actions 사용 가능 여부
- [ ] 한 구독을 여러 명이 공유한다면 `RG=rg-secretless-<이름>` 사용을 강제 (Key Vault/ACR 이름은 RG ID 기반으로 고유화됨)
- [ ] 당일 전 리허설 1회 (배포 ~5분, 파이프라인 ~4분)

## 타임테이블 (약 100분)

| 시간 | 내용 | 진행 팁 |
|---|---|---|
| 0:00 | 오프닝 + 모듈 0 | 로그인 이슈를 이 시간에 모두 해결 |
| 0:10 | 모듈 1 개념 (라이브 설명) | 시퀀스 다이어그램을 직접 그리며 설명. 체크포인트 질문 3개를 참석자에게 |
| 0:20 | 모듈 2 인프라 배포 | **배포 대기 3~5분 동안** main.bicep 을 함께 읽기 |
| 0:35 | 모듈 3 OIDC | `subject` 를 강조. 참석자에게 직접 subject 문자열을 말해보게 하기 |
| 0:50 | 모듈 4 파이프라인 | 배포 중 `Azure login` 로그를 함께 보기 |
| 1:05 | 모듈 5 장애 체험 | B, C, D 를 우선. 시간이 부족하면 A, B, D |
| 1:25 | 모듈 6 정리 + 회고 | 정리는 **반드시 수행** 하도록 안내 |

## 설명 포인트

- "Secretless" 는 **보관을 잘 하는 것** (Key Vault 에 클라이언트 시크릿 저장) 과 다릅니다. 그 시크릿에 접근하려면 또 다른 시크릿(부트스트랩 문제)이 필요하다는 점을 짚어 주세요.
- `client-id` 를 `vars` 에 두는 것에 의문을 가지는 참석자가 많습니다. **"ID 는 신분증 번호, 토큰은 서명된 증명서"** 비유 추천.
- `Contributor` 는 데모 편의를 위한 것입니다. 실무에서는 역할을 더 쪼개라고 안내하세요 (도전 과제 3).
- OIDC 와 Managed Identity 는 **서로 다른 문제를 푼다**: 전자는 "외부(GitHub) → Azure", 후자는 "Azure 내부 서비스 간".

## 자주 막히는 지점 TOP 5

1. 역할 할당 권한 부족 → 사전 점검
2. 저장소 이름 오타로 인한 subject 불일치 (`<owner>/<repo>` 대소문자 주의)
3. Codespaces `GITHUB_TOKEN` 때문에 `gh variable set` 실패
4. 역할 전파 지연으로 첫 배포 실패 → **Re-run jobs**
5. Fork 의 Actions 비활성화

## 행사 후

- 모든 참석자가 `03-cleanup.sh` 를 실행했는지 확인
- 공용 구독이라면 `rg-secretless-*` 잔존 리소스 그룹 점검:
  `az group list --query "[?starts_with(name,'rg-secretless')].name" -o tsv`
