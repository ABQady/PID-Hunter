//
//  RequestResponseMatcher.swift
//

import Foundation
import SwiftUI

struct PendingRequest {
    let timestamp: Date
    let header: String
    let command: String
}

@MainActor
final class RequestResponseMatcher: ObservableObject {
    
    static let shared = RequestResponseMatcher()
    
    @Published private(set) var pending: [PendingRequest] = []
    
    /// الطلبات الأقدم من 5 ثواني تعتبر منتهية
    private let timeout: TimeInterval = 5.0
    
    private func purgeExpired() {
        let now = Date()
        
        pending.removeAll {
            now.timeIntervalSince($0.timestamp) > timeout
        }
    }
    
    func enqueue(
        command: String,
        header: String
    ) {
        purgeExpired()
        
        pending.append(
            PendingRequest(
                timestamp: Date(),
                header: header,
                command: command
            )
        )
    }
    
    func dequeue() -> PendingRequest? {
        
        purgeExpired()
        
        guard !pending.isEmpty else {
            Logger.shared.info("⚠️ RX received with no pending request")
            return nil
        }
        
        return pending.removeFirst()
    }
    
    func clear() {
        pending.removeAll()
    }
}
