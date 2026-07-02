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

    private init() {}

    func reset() {

        requestsSent = 0
        responses = 0

        positiveResponses = 0
        negativeResponses = 0

        noData = 0
        busErrors = 0
        timeouts = 0

        startedAt = nil
        finishedAt = nil
        totalRequests = 0
    }
    
    func start() {
        guard startedAt == nil else { return }

        startedAt = .now
        finishedAt = nil
    }

    func finish() {
        guard finishedAt == nil else { return }
        finishedAt = .now
    }

    func elapsed(at now: Date) -> TimeInterval {
        guard let startedAt else { return 0 }
        return (finishedAt ?? now).timeIntervalSince(startedAt)
    }
    
    func averageRequestTime(at now: Date) -> TimeInterval {
        let elapsed = elapsed(at: now)
        guard requestsSent > 0, elapsed > 0 else {
            return 0
        }
        return elapsed / Double(requestsSent)
    }
    
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
    
    var positiveResponseRate: Double {

        guard requestsSent > 0 else {
            return 0
        }

        return Double(positiveResponses) * 100.0 /
               Double(requestsSent)
    }
    
    var failureRate: Double {

        guard requestsSent > 0 else {
            return 0
        }

        return max(0, min(100, 100 - positiveResponseRate))
    }
}
