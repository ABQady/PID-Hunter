//
//  ScanStatistics.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 27/06/2026.
//
import Foundation

@MainActor
final class ScanStatistics: ObservableObject {

    static let shared = ScanStatistics()

    @Published var requestsSent = 0
    @Published var responses = 0
    @Published var positiveResponses = 0
    @Published var negativeResponses = 0
    @Published var noData = 0
    @Published var busErrors = 0
    @Published var timeouts = 0

    @Published var startedAt: Date?
    @Published var finishedAt: Date?
    
    @Published var totalRequests = 0

    // MARK: - Lifecycle

    private init() {}

    func reset() {

        requestsSent = 0
        responses = 0

        positiveResponses = 0
        negativeResponses = 0
        noData = 0
        busErrors = 0
        timeouts = 0

        totalRequests = 0

        startedAt = nil
        finishedAt = nil
    }
    
    // MARK: - Timing

    /// Starts a new scan session and always resets the elapsed-time origin.
    /// Resume operations should preserve timing by avoiding this method.
    func start() {
        // A fresh scan must always establish a new timing origin.
        startedAt = .now
        finishedAt = nil
    }

    func finish() {
        guard finishedAt == nil else { return }
        finishedAt = .now
    }

    // MARK: - Derived Values

    @inline(__always)
    func elapsed(at now: Date) -> TimeInterval {
        guard let startedAt else { return 0 }
        return (finishedAt ?? now).timeIntervalSince(startedAt)
    }
    
    @inline(__always)
    func averageRequestTime(at now: Date) -> TimeInterval {
        let elapsed = elapsed(at: now)
        guard requestsSent > 0, elapsed > 0 else {
            return 0
        }
        return elapsed / Double(requestsSent)
    }
    
    @inline(__always)
    func eta(at now: Date) -> TimeInterval {
        let average = averageRequestTime(at: now)

        guard startedAt != nil,
              finishedAt == nil,
              requestsSent >= 10,
              totalRequests > requestsSent,
              average > 0 else {
            return 0
        }

        return average * Double(totalRequests - requestsSent)
    }
    
    @inline(__always)
    var positiveResponseRate: Double {

        guard requestsSent > 0 else {
            return 0
        }

        return Double(positiveResponses) * 100.0 /
               Double(requestsSent)
    }
    
    @inline(__always)
    var failureRate: Double {

        guard requestsSent > 0 else {
            return 0
        }

        return max(0, min(100, 100 - positiveResponseRate))
    }
    
    @inline(__always)
    var completionRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(requestsSent) * 100 / Double(totalRequests)
    }
    
    @inline(__always)
    var progressFraction: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(requestsSent) / Double(totalRequests)
    }

    @inline(__always)
    var isCompleted: Bool {
        finishedAt != nil
    }
    
    // MARK: - Recording

    func begin(totalRequests: Int) {
        reset()
        self.totalRequests = totalRequests
        start()
    }

    func recordPositiveResponse() {
        requestsSent += 1
        responses += 1
        positiveResponses += 1
    }

    func recordNegativeResponse() {
        requestsSent += 1
        responses += 1
        negativeResponses += 1
    }

    func recordNoData() {
        requestsSent += 1
        responses += 1
        noData += 1
    }

    func recordTimeout() {
        requestsSent += 1
        timeouts += 1
    }

    func recordBusError() {
        requestsSent += 1
        busErrors += 1
    }

    func complete() {
        finish()
    }
}
