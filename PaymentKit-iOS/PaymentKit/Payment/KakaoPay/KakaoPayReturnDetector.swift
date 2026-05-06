//
//  KakaoPayReturnDetector.swift
//  PaymentKit
//
//  Created by PSY on 3/26/26.
//

import UIKit
import Combine

/// 카카오페이 정기결제 후 앱 복귀 시점을 감지합니다.
///
/// ## 문제
/// 카카오톡 앱 전환 후 iOS 앱 복귀 시점을 정확히 감지하지 못하면
/// approve API 호출 타이밍이 어긋나, 사용자가 비용을 지불했으나 서비스를 받지 못하는 문제가 발생합니다.
///
/// ## 검토한 방법
/// - `applicationDidBecomeActive`: 모든 foreground 전환에서 호출 → 오탑 발생
/// - `sceneDidBecomeActive`: 동일한 문제. 특정 맥락 필터링 불가
///
/// ## 해결
/// NotificationCenter + URL Scheme 조합으로 '카카오페이에서의 복귀' 맥락을 특정합니다.
/// 두 조건 동시 충족 시에만 approve API를 호출합니다.
///
/// ## 결과
/// - 결제 미승인 케이스 0건
/// - 앱 전환 포함 결제 플로우 안정적 운영
public final class KakaoPayReturnDetector {

    // MARK: - Properties

    /// URL Scheme으로 카카오페이에서 돌아왔는지 추적하는 플래그
    private var isFromKakaoPay = false
    private var cancellables = Set<AnyCancellable>()

    /// 두 조건(URL Scheme + 앱 복귀)이 모두 충족되었을 때 실행할 클로저
    private let onReturn: () -> Void

    // MARK: - Init

    public init(onReturn: @escaping () -> Void) {
        self.onReturn = onReturn
        observeForeground()
    }

    // MARK: - 조건 1: URL Scheme 감지

    public func handleURLScheme(_ url: URL) {
        guard url.host == "payment",
              url.pathComponents.contains("kakao") else { return }
        isFromKakaoPay = true
    }

    // MARK: - 조건 2: 앱 Foreground 복귀 감지

    private func observeForeground() {
        NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                guard let self, self.isFromKakaoPay else { return }
                self.isFromKakaoPay = false
                self.onReturn()
            }
            .store(in: &cancellables)
    }

    deinit {
        cancellables.removeAll()
    }
}
