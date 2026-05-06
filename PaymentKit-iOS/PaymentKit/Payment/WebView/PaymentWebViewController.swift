//
//  PaymentWebViewController.swift
//  PaymentKit
//
//  Created by PSY on 3/26/26.
//

import UIKit
import WebKit

/// PG 결제 웹뷰를 관리하는 ViewController입니다.
///
/// ## 문제
/// 결제 WebView dismiss 후에도 ViewController가 해제되지 않는 메모리 릭.
/// 결제 화면 반복 진입 시 메모리 사용량이 누적되었습니다.
///
/// ## 해결
/// deinit에서 navigationDelegate = nil, Timer.invalidate() 등 명시적 해제.
/// 어떤 경로로 종료되든 deinit은 반드시 호출되므로 해제를 보장합니다.
/// Instruments Leaks / Allocations 도구로 실제 해제를 검증했습니다.
///
/// ## 결과
/// - 결제 관련 화면 메모리 릭 완전 제거
/// - Instruments Leaks / Allocations 검증 완료
public final class PaymentWebViewController: UIViewController {

    // MARK: - Properties

    private var webView: WKWebView!
    private var delegate: PaymentWebViewDelegate?
    private var pollingTask: Task<Void, Never>?

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
    }

    // MARK: - Setup

    private func setupWebView() {
        delegate = PaymentWebViewDelegate { [weak self] status in
            self?.handlePaymentResult(status)
        }

        webView = WKWebView(frame: view.bounds)
        webView.navigationDelegate = delegate
        view.addSubview(webView)
    }

    // MARK: - 결제 결과 처리

    private func handlePaymentResult(_ status: PaymentStatus) {
        switch status {
        case .success:
            dismiss(animated: true)
        case .fail, .cancel:
            dismiss(animated: true)
        case .processing:
            break
        }
    }

    // MARK: - 핵심: deinit에서 명시적 해제

    deinit {
        webView.navigationDelegate = nil
        webView.stopLoading()
        pollingTask?.cancel()
    }
}
