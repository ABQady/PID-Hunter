//
//  SmartSearchStrategy.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//


import Foundation

struct SmartSearchStrategy: SearchStrategy {

    let engineType: SearchEngineType = .smart
    private var queue = PIDQueue()
    private var visited: Set<UInt16> = []
    private var lastPositivePID: UInt16?
    private var positiveHitCount = 0

    /// Optional analytics engine used to bias future search decisions.
    /// Nil keeps the strategy operating exactly like the current implementation.
    private let analyzer: TelemetryAnalyzer?

    /// Tunable scoring coefficients. These will later be driven from Settings.
    struct ScoringWeights {
        var successWeight: Double = 1000
        var latencyWeight: Double = 1000
        var confidenceWeight: Double = 2
        var distanceWeight: Double = 1
    }

    private let scoring: ScoringWeights

    private let neighborhoodRadius: UInt16 = 3

    private var current: Int
    private let start: UInt16
    private let end: UInt16

    var isExhausted: Bool {
        queue.isEmpty && current > Int(end)
    }

    init(
        start: UInt16,
        end: UInt16,
        analyzer: TelemetryAnalyzer? = nil,
        scoring: ScoringWeights = .init()
    ) {
        precondition(start <= end)
        self.start = start
        self.end = end
        self.current = Int(start)
        self.analyzer = analyzer
        self.scoring = scoring
    }

    mutating func reset() {
        queue.clear()
        queue.reserveCapacity(64)
        visited.removeAll()
        lastPositivePID = nil
        positiveHitCount = 0
        current = Int(start)
    }

    // MARK: - Navigation
    mutating func seek(to pid: UInt16) {
        current = min(
            max(Int(pid), Int(start)),
            Int(end) + 1
        )
        queue.clear()
        visited.removeAll()
        lastPositivePID = nil
        positiveHitCount = 0
        queue.reserveCapacity(64)
    }

    // MARK: - PID Selection
    mutating func nextPID() -> UInt16? {
        while let pid = queue.dequeue() {
            if pid < start || pid > end {
                continue
            }

            guard visited.insert(pid).inserted else { continue }
            if Int(pid) > current {
                current = Int(pid)
            }
            return pid
        }

        while current <= Int(end) {
            let pid = UInt16(current)
            current += 1
            guard visited.insert(pid).inserted else { continue }
            return pid
        }

        return nil
    }

    private func radius(for pid: UInt16) -> UInt16 {
        guard let last = lastPositivePID else {
            return neighborhoodRadius
        }

        let distance = abs(Int(last) - Int(pid))
        guard distance <= Int(neighborhoodRadius) else {
            return neighborhoodRadius
        }

        let boosted = neighborhoodRadius + min(UInt16(positiveHitCount), neighborhoodRadius)
        let maxRadius = min(end - start, UInt16(16))
        return min(boosted, maxRadius)
    }

    // MARK: - Learning
    mutating func registerResult(
        pid: UInt16,
        result: SearchResult,
        latency: Double
    ) {
        guard case .positive = result else {
            _ = latency
            return
        }

        let radius = radius(for: pid)
        let statistics = analyzer?.statistics(for: pid)

        let effectiveRadius: UInt16
        if let statistics,
           statistics.isReliable,
           statistics.successRate > 0.8 {
            effectiveRadius = min(radius + 2, 16)
        } else {
            effectiveRadius = radius
        }

        lastPositivePID = pid
        positiveHitCount += 1

        _ = latency // Reserved for future latency-aware expansion.

        for neighbor in prioritizedNeighbors(
            around: pid,
            radius: effectiveRadius
        ) {
            enqueue(neighbor)
        }
    }

    private struct NeighborScore {
        let pid: UInt16
        let score: Double
        let successRate: Double
        let averageLatency: Double
        let requestCount: Int
        let distance: Int
    }

    private func calculateScore(
        successRate: Double,
        averageLatency: Double,
        requestCount: Int,
        distance: Int
    ) -> Double {
        let successComponent = successRate * scoring.successWeight
        let latencyComponent = averageLatency.isFinite
            ? (100 - averageLatency * scoring.latencyWeight)
            : -scoring.latencyWeight
        let confidenceComponent = min(Double(requestCount), 50) * scoring.confidenceWeight
        let distanceComponent = -Double(distance) * scoring.distanceWeight

        return successComponent
            + latencyComponent
            + confidenceComponent
            + distanceComponent
    }

    private func prioritizedNeighbors(
        around pid: UInt16,
        radius: UInt16
    ) -> [UInt16] {
        var candidates: [UInt16] = []

        for offset in 1...Int(radius) {
            let delta = UInt16(offset)

            if pid >= start + delta {
                candidates.append(pid - delta)
            }

            if pid <= end - delta {
                candidates.append(pid + delta)
            }
        }

        guard let analyzer else {
            return candidates
        }

        let scored = candidates.map { candidate in
            if let stats = analyzer.statistics(for: candidate) {
                let score = calculateScore(
                    successRate: stats.successRate,
                    averageLatency: stats.averageLatency,
                    requestCount: stats.requestCount,
                    distance: abs(Int(candidate) - Int(pid))
                )
                return NeighborScore(
                    pid: candidate,
                    score: score,
                    successRate: stats.successRate,
                    averageLatency: stats.averageLatency,
                    requestCount: stats.requestCount,
                    distance: abs(Int(candidate) - Int(pid))
                )
            }

            return NeighborScore(
                pid: candidate,
                score: -10_000,
                successRate: -1,
                averageLatency: .greatestFiniteMagnitude,
                requestCount: 0,
                distance: abs(Int(candidate) - Int(pid))
            )
        }

        return scored
            .sorted { $0.score > $1.score }
            .map(\.pid)
    }

    // MARK: - Queue Helpers
    private mutating func enqueue(_ pid: UInt16) {
        guard pid >= start, pid <= end else { return }
        guard !visited.contains(pid) else { return }
        guard !queue.contains(pid) else { return }
        queue.enqueue(pid)
    }
}
