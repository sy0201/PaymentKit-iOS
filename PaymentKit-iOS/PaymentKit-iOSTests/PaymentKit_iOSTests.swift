//
//  PaymentKit_iOSTests.swift
//  PaymentKit-iOSTests
//
//  Created by PSY on 3/13/26.
//

import XCTest
@testable import PaymentKit_iOS

// MARK: - Mock 객체

final class MockPaymentNetworking: PaymentNetworking {

    var paymentResult: Result<PaymentResponse, Error> = .success(
        PaymentResponse(status: .success)
    )

    var statusResult: Result<PaymentResponse, Error> = .success(
        PaymentResponse(status: .success)
    )

    var requestCallCount = 0

    func requestPayment(amount: Int) async throws -> PaymentResponse {
        requestCallCount += 1
        return try paymentResult.get()
    }

    func checkPaymentStatus(transactionId: String) async throws -> PaymentResponse {
        return try statusResult.get()
    }
}

// MARK: - 결제 6가지 케이스 테스트

final class PaymentServiceTests: XCTestCase {

    private var mockNetworking: MockPaymentNetworking!
    private var sut: PaymentService!

    override func setUp() {
        super.setUp()
        mockNetworking = MockPaymentNetworking()
        sut = PaymentService(networking: mockNetworking)
    }

    override func tearDown() {
        mockNetworking = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - 1. 결제 성공

    func test_결제성공_시_success_응답을_반환한다() async throws {
        mockNetworking.paymentResult = .success(
            PaymentResponse(status: .success, message: "결제가 완료되었습니다.")
        )

        let response = try await sut.requestPayment(amount: 10000, actionKey: "test_success")

        XCTAssertEqual(response.status, .success)
    }

    // MARK: - 2. 결제 실패

    func test_결제실패_시_fail_응답을_반환한다() async throws {
        mockNetworking.paymentResult = .success(
            PaymentResponse(status: .fail, message: "잔액이 부족합니다.")
        )

        let response = try await sut.requestPayment(amount: 10000, actionKey: "test_fail")

        XCTAssertEqual(response.status, .fail)
    }

    // MARK: - 3. 타임아웃

    func test_네트워크_타임아웃_시_에러를_던진다() async {
        mockNetworking.paymentResult = .failure(URLError(.timedOut))

        do {
            _ = try await sut.requestPayment(amount: 10000, actionKey: "test_timeout")
            XCTFail("에러가 발생해야 합니다.")
        } catch {
            XCTAssertTrue(error is URLError)
        }
    }

    // MARK: - 4. 결제 취소

    func test_결제취소_시_cancel_응답을_반환한다() async throws {
        mockNetworking.paymentResult = .success(
            PaymentResponse(status: .cancel, message: "사용자가 결제를 취소했습니다.")
        )

        let response = try await sut.requestPayment(amount: 10000, actionKey: "test_cancel")

        XCTAssertEqual(response.status, .cancel)
    }

    // MARK: - 5. 중복 탭 방어 (ButtonThrottler)

    func test_중복탭_시_두번째_요청은_차단된다() async throws {
        mockNetworking.paymentResult = .success(
            PaymentResponse(status: .success)
        )

        let first = try await sut.requestPayment(amount: 10000, actionKey: "test_throttle")
        let second = try await sut.requestPayment(amount: 10000, actionKey: "test_throttle")

        XCTAssertEqual(first.status, .success)
        XCTAssertEqual(second.status, .fail)
        XCTAssertEqual(second.message, "중복 요청이 차단되었습니다.")
        XCTAssertEqual(mockNetworking.requestCallCount, 1)
    }

    // MARK: - 6. 멱등성 (Idempotency-Key)

    func test_동일요청_재시도_시_중복결제가_발생하지_않는다() async throws {
        mockNetworking.paymentResult = .success(
            PaymentResponse(status: .success)
        )

        let response = try await sut.requestPayment(amount: 10000, actionKey: "test_idempotency_1")

        XCTAssertEqual(response.status, .success)
        XCTAssertEqual(mockNetworking.requestCallCount, 1)

        try await Task.sleep(for: .seconds(0.3))

        let retryResponse = try await sut.requestPayment(amount: 10000, actionKey: "test_idempotency_2")

        XCTAssertEqual(retryResponse.status, .success)
        XCTAssertEqual(mockNetworking.requestCallCount, 2)
    }
}
