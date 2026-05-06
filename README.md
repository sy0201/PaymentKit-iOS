# PaymentKit-iOS

실무에서 마주친 결제 시스템 문제를 해결한 모듈 모음

## 배경
카카오페이·토스페이먼츠 결제 연동 중 발생한
실제 문제를 해결한 구조적 해법을 담았습니다

---

## 프로젝트 구조

```
PaymentKit/
├── Payment/
│   ├── KakaoPay/
│   │   └── KakaoPayReturnDetector.swift    # 카카오페이 앱 복귀 감지
│   ├── WebView/
│   │   ├── PaymentWebViewDelegate.swift    # WKWebView 결제 상태 판별
│   │   └── PaymentWebViewController.swift  # retain cycle 해결
│   └── Networking/
│       ├── PaymentNetworking.swift         # Protocol 기반 DI
│       └── PaymentService.swift            # 결제 통합 서비스
├── Throttler/
│   └── ButtonThrottler.swift               # 중복 탭 방어 (NSLock)
├── Idempotency/
│   ├── IdempotencyKeyGenerator.swift       # UUID 기반 멱등성 키 생성
│   └── IdempotentRequestDecorator.swift    # 요청 헤더에 키 부착
├── Polling/
│   └── PaymentPollingService.swift         # async/await 폴링
├── Consultation/
│   └── ConsultationFlowCoordinator.swift   # Coordinator 패턴
└── ImageCache/
    └── CachedAsyncImage.swift              # SDWebImage 2단계 캐싱
```

---

## 1. ButtonThrottler + Idempotency-Key — 이중 방어

### 문제
어드민 데이터에서 0.2초 간격 중복 요청 발견
네트워크 타임아웃 후 자동 재시도 시 동일 요청 2회 도달

### 검토한 방법
| 방법 | 문제점 |
|------|--------|
| isUserInteractionEnabled | 예외 경로에서 복원 누락 시 영구 비활성화 |
| DispatchSemaphore | 단순 중복 탭 방지에 오버스펙 |

### 해결
- 1단계: NSLock 기반 ButtonThrottler (UI 레벨 방어)
- 2단계: UUID 기반 Idempotency-Key를 요청 헤더에 포함 (네트워크 레벨 방어)

### 결과
- 중복 데이터 생성 0건
- 앱 전체 12곳 통일 적용

---

## 2. 카카오페이 정기결제 — 앱 복귀 시점 감지

### 문제
카카오톡 앱 전환 후 iOS 앱 복귀 시점을 정확히 감지하지 못하면
approve API 호출 타이밍이 어긋나 결제 미승인 발생

### 검토한 방법
| 방법 | 문제점 |
|------|--------|
| applicationDidBecomeActive | 모든 foreground 전환에서 호출 → 오탑 발생 |
| sceneDidBecomeActive | 동일한 문제, 특정 맥락 필터링 불가 |

### 해결
NotificationCenter + URL Scheme 조합으로 '카카오페이에서의 복귀' 맥락을 특정
두 조건 동시 충족 시에만 approve API 호출

### 결과
- 결제 미승인 케이스 0건
- 앱 전환 포함 결제 플로우 안정적 운영

---

## 3. WKWebView 결제 상태 판별

### 문제
단일 콜백에서 URL 판별과 처리를 동시에 하다
리다이렉트가 빠른 PG사에서 완료 URL 누락

### 해결
decidePolicyFor (URL 판별 + 상태 저장) +
didCommit (로드 확정 후 처리) 역할 분리

### 결과
- 결제 미반영 버그 0건
- PG사별 성공/실패/취소 정확 판별

---

## 4. WKWebView retain cycle 해결

### 문제
결제 WebView dismiss 후에도 ViewController가 해제되지 않는 메모리 릭
결제 화면 반복 진입 시 메모리 사용량 누적

### 해결
deinit에서 navigationDelegate = nil, stopLoading(), Task.cancel() 명시적 해제
어떤 경로로 종료되든 deinit은 반드시 호출되므로 해제를 보장

### 결과
- 결제 관련 화면 메모리 릭 완전 제거
- Instruments Leaks / Allocations 검증 완료

---

## 5. PaymentPollingService — async/await 폴링 현대화

### 문제
DispatchQueue.asyncAfter 재귀 호출로
화면 이탈 시 취소 구조적 불가능
4개 화면에 동일 로직 240줄 중복

### 해결
async/await + Task.checkCancellation()
PaymentPollingService actor 단일 모듈로 통합

### 결과
- 240줄 → 60줄 (75% 감소)
- 화면 이탈 후 불필요 API 100% 제거
- [weak self] 콜백 중첩 완전 제거

---

## 6. Coordinator 패턴 — 약사 상담 플로우

### 문제
상담 진입점이 홈·프로모션·마이페이지에 분산
동일한 팝업 분기 로직이 복사-붙여넣기

### 해결
ConsultationFlowCoordinator 한 곳에 플로우 집중
진입점에서 startConsultation() 한 줄만 호출
팝업 문구 enum으로 중앙 관리

### 결과
- 수정 포인트 N곳 → 1곳 통합
- 신규 진입점 추가 시 한 줄 호출로 동일한 경험 제공

---

## 7. Protocol DI + XCTest — 결제 로직 테스트

### 문제
결제 케이스를 매번 실기기에서 수동 확인
1인 개발 환경에서 코드 리뷰 없이 회귀 버그 방지가 어려움

### 해결
Protocol 기반 DI + XCTest Mock 주입
init 파라미터에 기본값(= PaymentNetworkService()) 설정으로
기존 호출부 변경 0건, 100% 호환 유지

### 테스트 케이스
| # | 케이스 | 검증 내용 |
|---|--------|-----------|
| 1 | 결제 성공 | success 응답 반환 |
| 2 | 결제 실패 | fail 응답 반환 |
| 3 | 타임아웃 | URLError 에러 발생 |
| 4 | 결제 취소 | cancel 응답 반환 |
| 5 | 중복 탭 | ButtonThrottler가 두 번째 요청 차단 |
| 6 | 멱등성 | Idempotency-Key로 중복 결제 방지 |

### 결과
- 테스트 97% 단축 — 실기기 수동 → 로컬 자동
- 코드 변경 시 회귀 버그 자동 감지

---

## 8. SDWebImage 2단계 캐싱

### 문제
자체 Dictionary 캐시 — 메모리만 사용, 앱 재시작 시 전부 재다운로드
SwiftUI AsyncImage 20곳 — 캐싱 미동작, 스크롤마다 이미지 재다운로드

### 해결
SDWebImage 메모리 + 디스크 2단계 캐싱
캐시 히트 판별 후 스켈레톤 조건부 노출로 깜박임 제거

### 결과
- 캐시 히트 시 로딩 0.001초
- 이미지 네트워크 요청 약 80% 감소
- 앱 재시작 후 이미지 즉시 표시

---

## Tech Stack
Swift · async/await · NSLock · WKWebView · Combine · XCTest · SDWebImage · MVVM · Coordinator · Protocol DI
