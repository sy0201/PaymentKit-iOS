//
//  PaymentNetworking.swift
//  PaymentKit
//
//  Created by PSY on 3/26/26.
//

import Foundation

// MARK: - 결제 응답 모델

public enum PaymentResultStatus {
    case success
    case fail
    case timeout
    case cancel
}

public struct PaymentResponse {
    public let status: PaymentResultStatus
    public let message: String

    public init(status: PaymentResultStatus, message: String = "") {
        self.status = status
        self.message = message
    }
}

// MARK: - Protocol (결제 네트워크 추상화)

public protocol PaymentNetworking {
    func requestPayment(amount: Int) async throws -> PaymentResponse
    func checkPaymentStatus(transactionId: String) async throws -> PaymentResponse
}

// MARK: - 실제 구현체

public final class PaymentNetworkService: PaymentNetworking {

    public init() {}

    public func requestPayment(amount: Int) async throws -> PaymentResponse {
        // 실제 구현에서는 URLSession으로 PG사 API 호출
        fatalError("실제 PG사 API 연동 필요")
    }

    public func checkPaymentStatus(transactionId: String) async throws -> PaymentResponse {
        // 실제 구현에서는 결제 상태 확인 API 호출
        fatalError("실제 PG사 API 연동 필요")
    }
}
