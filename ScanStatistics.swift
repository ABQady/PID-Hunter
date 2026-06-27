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

    private init() {}

    func reset() {

        requestsSent = 0
        responses = 0

        positiveResponses = 0
        negativeResponses = 0

        noData = 0
        busErrors = 0
        timeouts = 0

        startedAt = Date()
        finishedAt = nil
    }

    func finish() {
        finishedAt = Date()
    }

    var elapsed: TimeInterval {

        guard let startedAt else { return 0 }

        return (finishedAt ?? Date())
            .timeIntervalSince(startedAt)
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

        return 100 - positiveResponseRate
    }
}
