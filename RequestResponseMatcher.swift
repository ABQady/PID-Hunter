//
//  RequestResponseMatcher.swift
//  PID Hunter By Ahmed AlQady

import Foundation
import SwiftUI

struct PendingRequest {
    let timestamp: Date
    let command: String
}


@MainActor
final class RequestResponseMatcher: ObservableObject {
    
    static let shared = RequestResponseMatcher()
    
    @Published private(set) var pending: [PendingRequest] = []
    var hasPending: Bool {
        !pending.isEmpty
    }
    
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
                command: command
            )
        )
    }
    
    func dequeue() -> PendingRequest? {
        purgeExpired()

        guard !pending.isEmpty else {
            return nil
        }

        return pending.removeFirst()
    }
    
    func clear() {
        pending.removeAll()
    }
}
