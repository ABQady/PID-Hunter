//
//  SearchStatistics.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//

import Foundation

struct SearchStatistics: Sendable, Codable {

    // MARK: - Requests

    private(set) var requestsSent: Int = 0
    private(set) var successfulResponses: Int = 0
    private(set) var failedResponses: Int = 0

    // MARK: - Derived Values
    @inline(__always)
    var completedRequests: Int {
        successfulResponses + failedResponses
    }

    @inline(__always)
    var successRate: Double {
        guard completedRequests > 0 else { return 0 }
        return Double(successfulResponses) / Double(completedRequests)
    }

    // MARK: - Discoveries

    private(set) var discoveredPIDs: Int = 0

    // MARK: - Timing

    private(set) var totalLatency: TimeInterval = 0
    private(set) var fastestResponse: TimeInterval = .greatestFiniteMagnitude
    private(set) var slowestResponse: TimeInterval = 0

    @inline(__always)
    var averageLatency: TimeInterval {
        guard successfulResponses > 0 else { return 0 }
        return totalLatency / Double(successfulResponses)
    }

    @inline(__always)
    var fastestSuccessfulResponse: TimeInterval {
        successfulResponses == 0 ? 0 : fastestResponse
    }

    @inline(__always)
    var hasSuccessfulResponses: Bool {
        successfulResponses > 0
    }

    @inline(__always)
    var hasFailures: Bool {
        failedResponses > 0
    }

    mutating func recordRequest() {
        requestsSent += 1
    }

    mutating func merge(with other: SearchStatistics) {
        requestsSent += other.requestsSent
        successfulResponses += other.successfulResponses
        failedResponses += other.failedResponses
        discoveredPIDs += other.discoveredPIDs
        totalLatency += other.totalLatency

        guard other.hasSuccessfulResponses else {
            return
        }

        if !hasSuccessfulResponses {
            fastestResponse = other.fastestResponse
            slowestResponse = other.slowestResponse
            return
        }

        fastestResponse = min(fastestResponse, other.fastestResponse)
        slowestResponse = max(slowestResponse, other.slowestResponse)
    }

    mutating func recordSuccess(latency: TimeInterval) {
        precondition(latency >= 0, "Latency cannot be negative")
        successfulResponses += 1
        totalLatency += latency
        fastestResponse = min(fastestResponse, latency)
        slowestResponse = max(slowestResponse, latency)
    }

    mutating func recordFailure() {
        failedResponses += 1
    }

    mutating func recordDiscovery() {
        discoveredPIDs += 1
    }

    mutating func record(result: SearchResult, latency: TimeInterval) {
        recordRequest()
        if case .positive = result {
            recordSuccess(latency: latency)
        } else {
            recordFailure()
        }
    }

    mutating func reset() {
        requestsSent = 0
        successfulResponses = 0
        failedResponses = 0
        discoveredPIDs = 0
        totalLatency = 0
        fastestResponse = .greatestFiniteMagnitude
        slowestResponse = 0
    }
}
