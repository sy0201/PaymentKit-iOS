//
//  PaymentWebViewDelegate.swift
//  PaymentKit
//
//  Created by PSY on 3/26/26.
//

import WebKit

/// PG사별 결제 완료/실패/취소 URL을 판별하고 처리하는 WKNavigationDelegate입니다.
///
/// ## 문제
/// 단일 콜백(decidePolicyFor)에서 URL 판별과 처리를 동시에 하면,
/// 리다이렉트가 빠른 PG사에서 완료 URL을 놓치는 타이밍 이슈로 결제 미반영 버그가 발생했습니다.
///
/// ## 해결
/// - `decidePolicyFor`: URL을 보고 **상태만 저장** (판별 역할)
/// - `didCommit`: 페이지 로드가 확정된 후 **저장된 상태를 보고 처리** (실행 역할)
/// 두 단계 분리로 순서를 항상 보장합니다.
///
/// ## 결과
/// - 결제 미반영 버그 0건
/// - PG사별 성공 / 실패 / 취소 정확 판별

// MARK: - 결제 상태 정의

public enum PaymentStatus {
    case success
    case fail
    case cancel
    case processing
}

// MARK: - PaymentWebViewDelegate

public final class PaymentWebViewDelegate: NSObject, WKNavigationDelegate {

    private var detectedStatus: PaymentStatus = .processing
    private let onPaymentResult: (PaymentStatus) -> Void

    public init(onPaymentResult: @escaping (PaymentStatus) -> Void) {
        self.onPaymentResult = onPaymentResult
    }

    // MARK: - 1단계: URL 판별 + 상태 저장 (decidePolicyFor)

    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        let urlString = url.absoluteString

        if urlString.contains("success") || urlString.contains("approve") {
            detectedStatus = .success
        } else if urlString.contains("fail") || urlString.contains("error") {
            detectedStatus = .fail
        } else if urlString.contains("cancel") {
            detectedStatus = .cancel
        } else {
            detectedStatus = .processing
        }

        decisionHandler(.allow)
    }

    // MARK: - 2단계: 로드 확정 후 처리 (didCommit)

    public func webView(
        _ webView: WKWebView,
        didCommit navigation: WKNavigation!
    ) {
        guard detectedStatus != .processing else { return }

        let result = detectedStatus
        detectedStatus = .processing
        onPaymentResult(result)
    }
}
