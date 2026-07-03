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

    var isReliable: Bool {
        requestCount >= 5
    }

    var latencySpread: TimeInterval {
        medianLatency - averageLatency
    }
}

extension PIDStatistics: Comparable {

    static func < (lhs: PIDStatistics, rhs: PIDStatistics) -> Bool {
        lhs.averageLatency < rhs.averageLatency
    }
}
