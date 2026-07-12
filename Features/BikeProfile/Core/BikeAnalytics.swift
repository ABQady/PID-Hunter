//
//  BikeAnalytics.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 11/07/2026.
//

import Foundation

struct BikeAnalytics {

    let profile: BikeProfile
    private let summary: Summary

    init(profile: BikeProfile) {
        self.profile = profile
        self.summary = Summary(profile: profile)
    }
    
    var firstSeen: Date {
        profile.firstSeen
    }

    var lastSeen: Date {
        profile.lastSeen
    }

    var fastestResponse: TimeInterval {
        summary.fastestResponse
    }

    var slowestResponse: TimeInterval {
        summary.slowestResponse
    }

    var positiveRatio: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(positiveRequests) / Double(totalRequests)
    }

    var negativeRatio: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(negativeRequests) / Double(totalRequests)
    }

    var noDataRatio: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(noDataRequests) / Double(totalRequests)
    }

    var dominantClassification: DiscoveryClassification {
        summary.dominantClassification
    }

    var weakestMode: String {
        summary.weakestMode
    }

    var communicationScore: Double {
        guard totalRequests > 0 else {
            return 0
        }

        let successWeight = successRate * 0.7

        let latencyWeight = max(
            0,
            1 - (averageLatency / 1.0)
        ) * 0.3

        return (successWeight + latencyWeight) * 100
    }

    var communicationScoreString: String {
        String(format: "%.0f%%", communicationScore)
    }

    var totalRequests: Int {
        summary.totalRequests
    }

    var positiveRequests: Int {
        summary.positiveRequests
    }

    var negativeRequests: Int {
        summary.negativeRequests
    }

    var noDataRequests: Int {
        summary.noDataRequests
    }

    var unknownRequests: Int {
        summary.unknownRequests
    }
    
    var partialResponseRequests: Int {
        summary.partialResponseRequests
    }

    var averageLatency: TimeInterval {
        summary.averageLatency
    }

    var successRate: Double {
        guard totalRequests > 0 else {
            return 0
        }

        return Double(positiveRequests) / Double(totalRequests)
    }

    var successRateString: String {
        String(format: "%.1f%%", successRate * 100)
    }

    var latencyString: String {
        "\(Int(averageLatency * 1000)) ms"
    }

    var coverage: Double {
        guard totalRequests > 0 else {
            return 0
        }

        return Double(totalRequests) / 65536.0
    }

    var coverageString: String {
        String(format: "%.2f%%", coverage * 100)
    }

    var strongestMode: String {
        summary.strongestMode
    }

    var modeBreakdown: [(mode: String, count: Int)] {
        summary.modeCounts
            .map { ($0.key, $0.value) }
            .sorted { $0.1 > $1.1 }
    }

    private struct Summary {

        let totalRequests: Int
        let positiveRequests: Int
        let negativeRequests: Int
        let noDataRequests: Int
        let unknownRequests: Int
        let partialResponseRequests: Int
        let averageLatency: TimeInterval
        let modeCounts: [String: Int]
        let strongestMode: String
        let weakestMode: String
        let fastestResponse: TimeInterval
        let slowestResponse: TimeInterval
        let dominantClassification: DiscoveryClassification

        init(profile: BikeProfile) {

            var positive = 0
            var negative = 0
            var noData = 0
            var unknown = 0
            var partialResponses = 0
            var latency: TimeInterval = 0
            var fastest = TimeInterval.greatestFiniteMagnitude
            var slowest: TimeInterval = 0
            var modes: [String: Int] = [:]

            for record in profile.discoveries {
                modes[record.mode, default: 0] += 1
                latency += record.averageLatency
                fastest = min(fastest, record.averageLatency)
                slowest = max(slowest, record.averageLatency)

                if record.hadPartialResponse {
                    partialResponses += 1
                }

                switch record.classification {
                case .positive:
                    positive += 1
                case .negative:
                    negative += 1
                case .noData:
                    noData += 1
                default:
                    unknown += 1
                }
            }

            totalRequests = profile.discoveries.count
            positiveRequests = positive
            negativeRequests = negative
            noDataRequests = noData
            unknownRequests = unknown
            partialResponseRequests = partialResponses
            averageLatency = totalRequests == 0 ? 0 : latency / Double(totalRequests)
            modeCounts = modes
            fastestResponse = totalRequests == 0 ? 0 : fastest
            slowestResponse = slowest
            strongestMode = modes.max(by: { $0.value < $1.value })?.key ?? "-"
            weakestMode = modes.min(by: { $0.value < $1.value })?.key ?? "-"

            let counts: [(DiscoveryClassification, Int)] = [
                (.positive, positive),
                (.negative, negative),
                (.noData, noData),
                (.unknown, unknown)
            ]

            dominantClassification = counts.max(by: { $0.1 < $1.1 })?.0 ?? .unknown
        }
    }
}
