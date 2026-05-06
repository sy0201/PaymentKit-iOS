//
//  PaymentPollingService.swift
//  PaymentKit
//
//  Created by PSY on 3/26/26.
//

import Foundation

// MARK: - Before (DispatchQueue.asyncAfter 기반)
//
// 4개 결제 화면에 아래와 동일한 폴링 로직이 60줄씩 복붙 — 총 240줄
//
// 문제점:
// 1. DispatchQueue.asyncAfter 기반 재귀 호출 → 화면 이탈 시 취소 구조적 불가능
// 2. [weak self] 콜백 중첩 2~4회 → 메모리 안전성 불확실
// 3. 4개 파일에 동일 로직 복붙 → 수정 시 4곳 모두 변경 필요
//
// private var pollCount = 0
// private let maxRetry = 4
// private var completion: ((Result<Void, PollingError>) -> Void)?
//
// func startPolling(completion: @escaping (Result<Void, PollingError>) -> Void) {
//     self.completion = completion
//     pollCount = 0
//     pollNext()
// }
//
// private func pollNext() {
//     guard pollCount < maxRetry else {
//         completion?(.failure(.timeout))
//         return
//     }
//     DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
//         guard let self else { return }
//         self.checkPaymentStatus { [weak self] isDone in
//             guard let self else { return }
//             if isDone {
//                 self.completion?(.success(()))
//             } else {
//                 self.pollCount += 1
//                 self.pollNext()
//             }
//         }
//     }
// }

// MARK: - After (async/await 기반)
//
// 개선 결과:
// 1. 240줄 → 60줄, 코드 중복 75% 감소
// 2. Task.checkCancellation()으로 화면 이탈 시 즉시 취소
// 3. [weak self] 콜백 중첩 완전 제거 — 메모리 안전성 구조적 보장
// 4. 단일 모듈로 4개 화면에서 재사용

public enum PollingError: Error {
    case timeout
    case cancelled
    case failed
}

public actor PaymentPollingService {
    public init() {}

    public func poll(maxRetry: Int = 4,
                     interval: TimeInterval = 2.0,
                     check: () async throws -> Bool) async throws {
        for _ in 0..<maxRetry {
            try Task.checkCancellation()

            let isDone = try await check()
            if isDone {
                return
            }

            try await Task.sleep(for: .seconds(interval))
        }
        throw PollingError.timeout
    }
}
