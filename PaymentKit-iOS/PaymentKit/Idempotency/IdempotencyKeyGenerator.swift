//
//  IdempotencyKeyGenerator.swift
//  PaymentKit
//
//  Created by PSY on 3/26/26.
//

import Foundation

public struct IdempotencyKeyGenerator {
    static func generate() -> String {
        UUID().uuidString
    }
}
