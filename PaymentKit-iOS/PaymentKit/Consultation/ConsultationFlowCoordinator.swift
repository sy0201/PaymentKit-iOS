//
//  ConsultationFlowCoordinator.swift
//  PaymentKit
//
//  Created by PSY on 3/26/26.
//

import UIKit

// MARK: - Before (VC에서 직접 push / present)
//
// 상담 진입점이 홈·프로모션·마이페이지에 분산되어
// 동일한 팝업 분기 로직이 복사-붙여넣기 되어 있었습니다.
//
// // HomeViewController.swift
// if user.isSubscribed {
//     let vc = ConsultationViewController()
//     navigationController?.pushViewController(vc, animated: true)
// } else if user.hasFreeTrial {
//     showAlert("무료체험 해보세요") { ... }
// } else {
//     showAlert("구독이 필요합니다")
// }
//
// // PromotionViewController.swift — 동일 로직 복붙
// // MyPageViewController.swift — 동일 로직 복붙

// MARK: - After (Coordinator 패턴)
//
// 개선 결과:
// 1. 수정 포인트 N곳 → 1곳 통합
// 2. 신규 진입점 추가 시 한 줄 호출로 동일한 경험 제공
// 3. 플로우 비즈니스 로직 독립 테스트 가능

// MARK: - 상담 팝업 문구 중앙 관리

public enum ConsultationAlert {
    case needSubscription
    case freeTrialAvailable
    case alreadyInConsultation

    var title: String {
        switch self {
        case .needSubscription:      return "구독이 필요합니다"
        case .freeTrialAvailable:    return "무료체험 가능"
        case .alreadyInConsultation: return "상담 진행 중"
        }
    }

    var message: String {
        switch self {
        case .needSubscription:      return "약사 상담은 구독 회원만 이용할 수 있습니다."
        case .freeTrialAvailable:    return "첫 상담은 무료로 체험해보세요!"
        case .alreadyInConsultation: return "이미 진행 중인 상담이 있습니다."
        }
    }
}

// MARK: - ConsultationFlowCoordinator

public final class ConsultationFlowCoordinator {

    private weak var navigationController: UINavigationController?

    public init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    public func startConsultation(isSubscribed: Bool, hasFreeTrial: Bool, isInConsultation: Bool) {
        if isInConsultation {
            showAlert(.alreadyInConsultation)
        } else if isSubscribed {
            pushConsultationScreen()
        } else if hasFreeTrial {
            showAlert(.freeTrialAvailable) { [weak self] in
                self?.pushConsultationScreen()
            }
        } else {
            showAlert(.needSubscription)
        }
    }

    // MARK: - Private

    private func pushConsultationScreen() {
        let consultationVC = ConsultationViewController()
        navigationController?.pushViewController(consultationVC, animated: true)
    }

    private func showAlert(_ type: ConsultationAlert, onConfirm: (() -> Void)? = nil) {
        let alert = UIAlertController(title: type.title, message: type.message, preferredStyle: .alert)

        if let onConfirm {
            alert.addAction(UIAlertAction(title: "시작하기", style: .default) { _ in onConfirm() })
            alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        } else {
            alert.addAction(UIAlertAction(title: "확인", style: .default))
        }

        navigationController?.present(alert, animated: true)
    }
}

// MARK: - ConsultationViewController

final class ConsultationViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "약사 상담"
        view.backgroundColor = .systemBackground
    }
}
