# PaymentKit-iOS

이 저장소는 실무에서 다룬 결제 관련 문제를, 회사 코드를 공개할 수 없어 핵심 구조만 재구성한 예제입니다. 프로덕션 코드가 아닙니다.

일부 모듈은 실제 서비스에 반영한 방식이고, 일부(예: `PaymentPollingService`)는 실무에서 겪은 한계를 개선하기 위해 직접 설계·구현한 것으로 실 서비스에는 반영하지 않았습니다. 각 항목에 구분해 표기했습니다.

## 배경
카카오페이·토스페이먼츠 결제 연동 중 마주친 실제 문제와, 그에 대한 구조적 해법을 담았습니다.

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
│   └── PaymentPollingService.swift         # async/await 폴링 (개선 설계)
├── Consultation/
│   └── ConsultationFlowCoordinator.swift   # Coordinator 패턴
└── ImageCache/
    └── CachedAsyncImage.swift              # SDWebImage 2단계 캐싱
```

---

## 1. ButtonThrottler + Idempotency-Key — 이중 방어

### 문제
어드민 데이터에서 0.2초 간격 중복 요청 발견.
네트워크 타임아웃 후 자동 재시도 시 동일 요청이 서버에 2회 도달.

### 검토한 방법
| 방법 | 한계 |
|------|--------|
| 버튼 비활성화(UIKit isEnabled / SwiftUI .disabled()) | 예외 경로에서 다시 활성화하지 못하면 영구 비활성화 |
| DispatchSemaphore | 스레드를 멈추는 방식이라 단순 탭 방지에는 과도 |

### 해결
- 1단계(UI): NSLock으로 보호한 딕셔너리에 키별 마지막 탭 시각을 저장하고, 0.5초 내 재탭을 무시하는 ButtonThrottler
- 2단계(네트워크): 요청마다 UUID를 만들어 Idempotency-Key 헤더에 실어, 재시도가 와도 서버가 한 번만 처리

### 결과
- UI와 네트워크 양쪽에서 중복 요청을 거르는 구조
- 한 번만 눌려야 하는 자리(결제·리뷰 등록·구독 신청 등) 12곳에 동일하게 적용

---

## 2. 카카오페이 정기결제 — 앱 복귀 시점 감지

### 문제
카카오톡 앱으로 전환해 결제한 뒤 앱으로 돌아오는 시점을 정확히 감지하지 못하면,
이후 결제 결과 확인 처리의 타이밍이 어긋남.

### 검토한 방법
| 방법 | 한계 |
|------|--------|
| didBecomeActive 단독 사용 | 컨트롤 센터 등 모든 foreground 전환에서 호출돼 오탑 발생 |
| sceneDidBecomeActive 단독 사용 | 동일한 문제, '카카오페이에서의 복귀' 맥락만 걸러낼 수 없음 |

### 해결
- `decidePolicyFor`에서 `kakaotalk://` 스킴을 감지하면 "카카오톡을 실행했다" 플래그를 설정
- `UIApplication.didBecomeActiveNotification`으로 앱 복귀를 감지하되, 위 플래그가 켜져 있을 때만 이후 처리를 진행
- didBecomeActive가 모든 활성화에서 호출되는 문제는 이 플래그로 걸러, '카카오페이에서의 복귀' 맥락만 통과시킴

### 결과
- 카카오톡 앱 전환을 포함한 결제 플로우에서 복귀 시점을 특정해 처리
- URL Scheme 감지와 앱 생명주기 알림을 조합해, 앱 전환 없이도 동일한 흐름으로 판별

---

## 3. WKWebView 결제 상태 판별

### 문제
단일 콜백(`decidePolicyFor`)에서 URL 판별과 처리를 동시에 하면,
리다이렉트가 빠른 PG사에서 완료 URL이 로드되기 전에 처리가 먼저 실행됨.

### 해결
- `decidePolicyFor`: URL을 보고 **상태만 기록** (판별 역할)
- `didFinish` / `didCommit`: 페이지 로드가 확정된 후 **기록된 상태를 처리** (실행 역할)
- 두 단계를 나눠 "기록 먼저, 처리 나중" 순서를 고정

### 결과
- 네트워크 속도와 무관하게 처리 순서가 유지되는 구조
- 성공 / 실패 / 취소 상태를 PG사와 무관하게 같은 방식으로 구분

---

## 4. WKWebView retain cycle 해결

### 문제
결제 WebView를 dismiss한 뒤에도 ViewController가 해제되지 않아,
결제 화면에 반복 진입할수록 메모리 사용량이 누적됨.

### 해결
- `deinit`에서 `navigationDelegate = nil`, `stopLoading()`, NotificationCenter 옵저버 제거, 진행 중 작업 취소를 명시적으로 수행
- 어떤 경로로 종료되든 `deinit`은 호출되므로 해제 지점을 한 곳으로 모음

### 결과
- 종료 경로와 무관하게 델리게이트·옵저버·로딩을 해제하는 구조
- Instruments(Leaks / Allocations)로 화면 종료 후 객체 해제 여부를 확인

---

## 5. PaymentPollingService — async/await 폴링 (개선 설계)

> 실무에서는 이 폴링을 DispatchQueue.asyncAfter 재귀로 구현했습니다.
> 아래 async/await 버전은 그 한계를 개선하기 위해 직접 설계·구현한 것으로, **실 서비스에는 반영하지 않았습니다.**

### 문제 (실무)
- DispatchQueue.asyncAfter 재귀 호출 구조라, 화면을 벗어나도 폴링 취소가 구조적으로 전파되지 않음
- 같은 폴링 로직이 여러 화면에 복사돼 있어 수정 지점이 분산

### 개선 설계
- async/await + `Task.checkCancellation()`으로 "기다림 → 상태 확인 → 반복"을 그대로 표현
- 화면 이탈 시 취소가 자동 전파되도록 구성
- 여러 곳에서 동시에 접근해도 충돌하지 않도록 `actor` 기반 단일 서비스로 분리

### 결과
- 화면 이탈 시 취소가 전파돼 무한 로딩이 구조적으로 발생하지 않는 구조
- 흩어질 폴링 로직을 하나의 서비스로 모을 수 있는 구조
- 실무에서 겪은 한계를 개선 방향으로 코드에 옮겨 검증한 사례

---

## 6. Coordinator 패턴 — 약사 상담 플로우

### 문제
상담 진입점이 홈·프로모션·마이페이지에 분산되어,
동일한 팝업 분기 로직이 진입점마다 복사됨.

### 해결
- `ConsultationFlowCoordinator` 한 곳으로 플로우를 모음
- 진입점에서는 `startConsultation()` 한 줄만 호출
- 팝업 문구·분기는 enum으로 중앙 관리, 순환 참조 방지를 위해 weak로 관계 설정

### 결과
- 수정 지점이 여러 곳에서 한 곳으로 통합
- 신규 진입점이 생겨도 기존 코드 변경 없이 동일한 상담 흐름에 연결

---

## 7. Protocol DI + XCTest — 결제 로직 테스트

### 문제
결제 케이스를 매번 실기기에서 수동으로 확인.
1인 개발 환경이라 코드 수정 후 회귀를 검증할 방법이 없었음.

### 해결
- Protocol 기반 DI + XCTest Mock 주입
- init 파라미터에 기본값(`= PaymentNetworkService()`)을 지정해, 기존 호출부를 변경하지 않고 테스트 시에만 Mock 교체

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
- 실기기 수동 확인을 로컬 자동 테스트로 대체
- 코드 변경 시 회귀를 자동으로 검출

---

## 8. SDWebImage 2단계 캐싱

### 문제
자체 Dictionary 캐시는 메모리만 사용해, 앱을 재시작하면 이미지를 전부 재다운로드.
SwiftUI AsyncImage 사용처에서 캐싱이 동작하지 않아 스크롤마다 재다운로드.

### 해결
- 자체 Dictionary 캐시를 SDWebImage(메모리 + 디스크 2단계 캐싱)로 교체
- 캐시 히트 여부를 판별해 스켈레톤을 조건부로 노출, 깜빡임 제거

### 결과
- 반복 다운로드 감소, 앱 재시작 후에도 이미지 즉시 표시
- 스크롤 시 이미지 깜빡임 정리

---

## Tech Stack
Swift · async/await · NSLock · WKWebView · Combine · XCTest · SDWebImage · MVVM · Coordinator · Protocol DI
