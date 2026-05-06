//
//  PaymentService.swift
//  PaymentKit
//
//  Created by PSY on 3/26/26.
//

import Foundation

/// 결제 요청과 상태 확인을 담당하는 서비스입니다.
///
/// ## Protocol DI 적용
/// `init(networking:)` 파라미터에 기본값 `= PaymentNetworkService()`를 설정하여
/// 기존 호출부는 변경 0건, 100% 호환을 유지합니다.
public final class PaymentService {

    private let networking: PaymentNetworking
    private let throttler = ButtonThrottler.shared
    private let pollingService = PaymentPollingService()

    public init(networking: PaymentNetworking = PaymentNetworkService()) {
        self.networking = networking
    }

    // MARK: - 결제 요청

    public func requestPayment(amount: Int, actionKey: String) async throws -> PaymentResponse {
        // 1단계: UI 레벨 방어
        guard throttler.canExecute(for: actionKey) else {
            return PaymentResponse(status: .fail, message: "중복 요청이 차단되었습니다.")
        }

        // 2단계: 네트워크 레벨 방어 (Idempotency-Key는 내부에서 적용)
        let response = try await networking.requestPayment(amount: amount)
        return response
    }

    // MARK: - 결제 상태 폴링

    public func pollPaymentStatus(transactionId: String) async throws -> PaymentResponse {
        var finalResponse = PaymentResponse(status: .timeout, message: "폴링 시간 초과")

        try await pollingService.poll { [networking] in
            let response = try await networking.checkPaymentStatus(transactionId: transactionId)
            if response.status == .success || response.status == .fail {
                finalResponse = response
                return true
            }
            return false
        }

        return finalResponse
    }
}
