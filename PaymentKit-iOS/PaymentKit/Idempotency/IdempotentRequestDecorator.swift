//
//  IdempotentRequestDecorator.swift
//  PaymentKit-iOS
//
//  Created by PSY on 5/6/26.
//

import Foundation

public struct IdempotentRequestDecorator {

    private static let headerKey = "Idempotency-Key"

    public static func decorate(_ request: URLRequest) -> URLRequest {
        var decorated = request
        let key = IdempotencyKeyGenerator.generate()
        decorated.setValue(key, forHTTPHeaderField: headerKey)
        return decorated
    }
}
