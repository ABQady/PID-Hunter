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

    let averageLatency: Double

    let medianLatency: Double

    let successRate: Double

    let firstSeen: Date

    let lastSeen: Date

    // MARK: - Reliability
    @inline(__always)
    var isReliable: Bool {
        requestCount >= 5
    }

    // MARK: - Derived Values
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
