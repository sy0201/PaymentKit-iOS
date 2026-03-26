# PaymentKit-iOS

실무에서 마주친 결제 시스템 문제를 해결한 모듈 모음

## 배경
카카오페이·토스페이먼츠 결제 연동 중 발생한 
실제 문제를 해결한 구조적 해법을 담았습니다

---

## 1. ButtonThrottler — 중복 결제 방어

### 문제
어드민 데이터에서 0.2초 간격 중복 요청 발견
네트워크 타임아웃 후 자동 재시도 시 동일 요청 2회 도달

### 검토한 방법
| 방법 | 문제점 |
|------|--------|
| isUserInteractionEnabled | 예외 경로에서 복원 누락 시 영구 비활성화 |
| DispatchSemaphore | 단순 중복 탭 방지에 오버스펙 |

### 해결
NSLock 기반 ButtonThrottler (UI 레벨) +
Idempotency-Key (네트워크 레벨) 이중 방어

### 결과
- 중복 데이터 생성 0건
- 앱 전체 12곳 통일 적용

---

## 2. PaymentPollingService — async/await 폴링 현대화

### 문제
DispatchQueue.asyncAfter 재귀 호출로
화면 이탈 시 취소 구조적 불가능
4개 화면에 동일 로직 240줄 중복

### 해결
async/await + Task.checkCancellation()
PaymentPollingService 단일 모듈로 통합

### 결과
- 240줄 → 60줄 (75% 감소)
- 화면 이탈 후 불필요 API 100% 제거

---

## 3. WKWebView 결제 상태 판별

### 문제
단일 콜백에서 URL 판별과 처리를 동시에 하다
리다이렉트가 빠른 PG사에서 완료 URL 누락

### 해결
decidePolicyFor (URL 판별) +
didCommit (처리) 역할 분리

### 결과
- 결제 미반영 버그 0건
- PG사별 성공/실패/취소 정확 판별

---

## Tech Stack
Swift · async/await · NSLock · WKWebView · XCTest
