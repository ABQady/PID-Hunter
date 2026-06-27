//
//  RequestResponseMatcher.swift
//  PID Hunter By Ahmed AlQady
//

import Foundation
import SwiftUI

struct PendingRequest {
    let timestamp: Date
    let command: String
    let header: String
}

@MainActor
final class RequestResponseMatcher: ObservableObject {

    static let shared = RequestResponseMatcher()

    @Published private(set) var pending: [PendingRequest] = []

    var hasPending: Bool {
        head < pending.count
    }

    private let timeout: TimeInterval = 15

    private var head = 0

    private func purgeExpired() {

        let now = Date()

        while head < pending.count {

            let request = pending[head]

            if now.timeIntervalSince(request.timestamp) <= timeout {
                break
            }

            Logger.shared.info("Queue Timeout: \(request.command)")
            head += 1
        }

        compactIfNeeded()
    }

    private func compactIfNeeded() {

        guard head >= 256 else {
            return
        }

        pending.removeFirst(head)
        head = 0
    }

    func enqueue(
        command: String,
        header: String
    ) {

        purgeExpired()

        let request = PendingRequest(
            timestamp: Date(),
            command: command,
            header: header
        )

        pending.append(request)

        Logger.shared.info(
            "Queue + \(command) [\(header)]"
        )
    }

    func dequeue() -> PendingRequest? {

        purgeExpired()

        guard head < pending.count else {
            return nil
        }

        let request = pending[head]
        head += 1

        Logger.shared.info(
            "Queue - \(request.command) [\(request.header)]"
        )

        compactIfNeeded()

        return request
    }

    var first: PendingRequest? {

        purgeExpired()

        guard head < pending.count else {
            return nil
        }

        return pending[head]
    }

    func clear() {

        pending.removeAll()
        head = 0
    }
}
