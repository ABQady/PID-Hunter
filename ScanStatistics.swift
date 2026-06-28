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
        objectWillChange.send()
        totalRequests = 0
    }
    
    func start() {
        startedAt = .now
        finishedAt = nil
    }

    func finish() {
        if finishedAt == nil {
            finishedAt = Date()
        }
    }

    var elapsed: TimeInterval {

        guard let startedAt else { return 0 }

        return (finishedAt ?? Date())
            .timeIntervalSince(startedAt)
    }
    
    var averageRequestTime: TimeInterval {
        guard requestsSent > 0, elapsed > 0 else {
            return 0
        }

        return elapsed / Double(requestsSent)
    }
    
    var eta: TimeInterval {
        guard startedAt != nil,
              finishedAt == nil,
              requestsSent >= 10,
              totalRequests > requestsSent,
              averageRequestTime > 0 else {
            return 0
        }
        return averageRequestTime * Double(totalRequests - requestsSent)
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
