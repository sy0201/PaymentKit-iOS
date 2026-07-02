//
//  KakaoPayReturnDetector.swift
//  PaymentKit
//

import UIKit
import Combine

/// 카카오페이 정기결제 시, 카카오톡 앱으로 전환했다가 다시 우리 앱으로
/// 복귀하는 시점을 감지합니다.
///
/// ## 문제
/// 카카오톡 앱에서 결제한 뒤 우리 앱으로 돌아오는 시점을 정확히 잡지 못하면,
/// 이후 결제 결과 확인 처리의 타이밍이 어긋납니다.
///
/// ## 검토한 방법
/// - `didBecomeActive` 단독: 컨트롤 센터를 내렸다 올리는 등 모든 foreground
///   전환에서 호출되어, '카카오페이에서의 복귀'가 아닌데도 처리가 실행되는
///   오탑(false positive)이 발생합니다.
/// - `sceneDidBecomeActive` 단독: 동일한 문제. 특정 맥락만 걸러낼 수 없습니다.
///
/// ## 해결
/// 앱 생명주기 알림 하나만으로는 맥락을 구분할 수 없으므로, URL Scheme 감지로
/// 얻은 플래그를 조건으로 함께 겁니다.
/// 1. 웹뷰가 `kakaotalk://` 스킴으로 외부 앱을 여는 순간을 감지해
///    `isKakaoTalkLaunched` 플래그를 세웁니다. (= "지금 카카오톡으로 나갔다")
/// 2. `UIApplication.didBecomeActiveNotification`으로 앱 복귀를 감지하되,
///    위 플래그가 켜져 있을 때만 복귀로 판단하고 처리를 진행합니다.
///
/// 즉 `didBecomeActive`가 모든 활성화에서 불리는 문제를 이 플래그로 걸러,
/// '카카오페이에서의 복귀' 맥락만 통과시킵니다.
///
/// ## 참고
/// 이 저장소는 실무 구조를 공개용으로 재구성한 예제입니다. 복귀 이후 실제
/// 결제 결과 판별(웹뷰 URL 확인 등)은 호출부가 `onReturn` 안에서 담당합니다.
public final class KakaoPayReturnDetector {

    // MARK: - Properties

    /// 카카오톡 앱으로 전환했는지 추적하는 플래그.
    /// didBecomeActive가 모든 활성화에서 불리는 문제를 이 플래그로 걸러낸다.
    private var isKakaoTalkLaunched = false

    private var cancellables = Set<AnyCancellable>()

    /// 카카오톡에서 복귀한 것으로 판단됐을 때 실행할 클로저
    private let onReturn: () -> Void

    // MARK: - Init

    public init(onReturn: @escaping () -> Void) {
        self.onReturn = onReturn
        observeDidBecomeActive()
    }

    deinit {
        cancellables.removeAll()
    }

    // MARK: - 조건 1: 카카오톡 앱 전환 감지 (URL Scheme)

    /// 웹뷰가 외부 앱을 여는 시점에 호출한다.
    /// `kakaotalk://` 스킴이면 "카카오톡으로 나갔다"고 표시해둔다.
    public func handleOpeningExternalApp(_ url: URL) {
        guard url.scheme == "kakaotalk" else { return }
        isKakaoTalkLaunched = true
    }

    // MARK: - 조건 2: 앱 복귀 감지 (didBecomeActive)

    private func observeDidBecomeActive() {
        NotificationCenter.default
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self, self.isKakaoTalkLaunched else { return }
                // 플래그를 먼저 내려 같은 복귀가 두 번 처리되지 않게 한다.
                self.isKakaoTalkLaunched = false
                self.onReturn()
            }
            .store(in: &cancellables)
    }
}
