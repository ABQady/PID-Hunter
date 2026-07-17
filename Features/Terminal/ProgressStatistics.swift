//
//  ProgressStatistics.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 17/07/2026.
//

import Foundation
import Observation
import Combine

@MainActor
final class ProgressStatistics: ObservableObject {
    
    static let shared = ProgressStatistics()
    private init() {}
    
    @Published private(set) var total: Int = 0
    @Published private(set) var completed: Int = 0
    @Published private(set) var successes: Int = 0
    @Published private(set) var failures: Int = 0

    @Published private(set) var startedAt: Date?
    @Published private(set) var finishedAt: Date?

    var isRunning: Bool {
        startedAt != nil && finishedAt == nil
    }

    var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var elapsed: TimeInterval {
        guard let startedAt else { return 0 }
        return (finishedAt ?? Date()).timeIntervalSince(startedAt)
    }

    var averageDuration: TimeInterval {
        guard completed > 0 else { return 0 }
        return elapsed / Double(completed)
    }

    var remaining: Int {
        max(total - completed, 0)
    }

    var estimatedRemaining: TimeInterval {
        guard completed > 0 else { return 0 }
        return averageDuration * Double(remaining)
    }

    func start(total: Int) {
        self.total = total
        completed = 0
        successes = 0
        failures = 0

        startedAt = Date()
        finishedAt = nil
    }

    func record(success: Bool) {
        guard completed < total else { return }

        completed += 1

        if success {
            successes += 1
        } else {
            failures += 1
        }
    }

    func update(completed: Int) {
        self.completed = max(0, min(completed, total))
    }

    func finish() {
        finishedAt = Date()
    }

    func reset() {
        total = 0
        completed = 0
        successes = 0
        failures = 0

        startedAt = nil
        finishedAt = nil
    }
}
