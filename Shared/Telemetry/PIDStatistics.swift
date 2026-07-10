//
//  PIDStatistics.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 03/07/2026.
//
import Foundation

struct PIDStatistics {

    let pid: UInt16

    let requestCount: Int
    let responseCount: Int

    let positiveCount: Int
    let negativeCount: Int
    let noDataCount: Int
    let timeoutCount: Int
    let transportErrorCount: Int

    let averageLatency: Double
    let medianLatency: Double

    let firstSeen: Date
    let lastSeen: Date

    // MARK: - Derived Values

    @inline(__always)
    var successRate: Double {
        guard responseCount > 0 else { return 0 }
        return Double(positiveCount) / Double(responseCount)
    }

    @inline(__always)
    var isReliable: Bool {
        requestCount >= 5
    }

    @inline(__always)
    var latencySpread: TimeInterval {
        medianLatency - averageLatency
    }

    @inline(__always)
    var latencyVariance: Double {
        abs(latencySpread)
    }
}

// MARK: - Comparable
extension PIDStatistics: Comparable {

    @inline(__always)
    static func < (lhs: PIDStatistics, rhs: PIDStatistics) -> Bool {
        lhs.averageLatency < rhs.averageLatency
    }
}
