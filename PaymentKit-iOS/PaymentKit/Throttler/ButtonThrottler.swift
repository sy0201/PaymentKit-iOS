//
//  ButtonThrottler.swift
//  PaymentKit
//
//  Created by PSY on 3/13/26.
//

import Foundation

final class ButtonThrottler {
    
    static let shared = ButtonThrottler()
    
    private var lastTapTime: [String: Date] = [:]
    private let lock = NSLock()
    private let throttleInterval: TimeInterval
    
    private init(throttleInterval: TimeInterval = 0.5) {
        self.throttleInterval = throttleInterval
    }
    
    func canExecute(for key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let now = Date()
        if let last = lastTapTime[key],
           now.timeIntervalSince(last) < throttleInterval {
            return false
        }
        lastTapTime[key] = now
        return true
    }
    
    func reset(for key: String) {
        lock.lock()
        defer { lock.unlock() }
        lastTapTime.removeValue(forKey: key)
    }
}
