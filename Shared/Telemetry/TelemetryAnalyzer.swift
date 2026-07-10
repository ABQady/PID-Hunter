//
//  TelemetryAnalyzer.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 03/07/2026.
//

final class TelemetryAnalyzer {

    private let telemetry: [RequestTelemetry]
    private static let neighborhoodRadius = 8

    private lazy var groupedByPID: [UInt16: [RequestTelemetry]] = {
        Dictionary(grouping: telemetry, by: \.pid)
    }()
    
    private lazy var statisticsCache: [UInt16: PIDStatistics] = {
        groupedByPID.mapValues(makeStatistics)
    }()

    init(telemetry: [RequestTelemetry]) {
        self.telemetry = telemetry
    }

    // MARK: - Statistics

    private func averageLatency(for samples: [RequestTelemetry]) -> Double {
        guard !samples.isEmpty else { return 0 }
        return samples.map(\.latency).reduce(0, +) / Double(samples.count)
    }

    private var averageLatencyByPID: [(pid: UInt16, latency: Double)] {
        groupedByPID.map { pid, samples in
            (pid: pid, latency: averageLatency(for: samples))
        }
    }

    private func medianLatency(for samples: [RequestTelemetry]) -> Double {
        let values = samples.map(\.latency).sorted()
        guard !values.isEmpty else { return 0 }

        let middle = values.count / 2
        if values.count.isMultiple(of: 2) {
            return (values[middle - 1] + values[middle]) / 2
        }
        return values[middle]
    }

    private func successRate(for samples: [RequestTelemetry]) -> Double {
        guard !samples.isEmpty else { return 0 }

        let successes = samples.filter {
            if case .positive = $0.classification {
                return true
            }
            return false
        }.count

        return Double(successes) / Double(samples.count)
    }

    private func makeStatistics(
        for samples: [RequestTelemetry]
    ) -> PIDStatistics {
        PIDStatistics(
            pid: samples.first!.pid,
            requestCount: samples.count,
            responseCount: samples.filter {
                switch $0.classification {
                case .positive, .negative, .noData:
                    return true
                default:
                    return false
                }
            }.count,
            positiveCount: samples.filter {
                if case .positive = $0.classification { return true }
                return false
            }.count,
            negativeCount: samples.filter {
                if case .negative = $0.classification { return true }
                return false
            }.count,
            noDataCount: samples.filter {
                if case .noData = $0.classification { return true }
                return false
            }.count,
            timeoutCount: samples.filter {
                if case .timeout = $0.classification { return true }
                return false
            }.count,
            transportErrorCount: samples.filter {
                if case .adapter = $0.classification { return true }
                return false
            }.count,
            averageLatency: averageLatency(for: samples),
            medianLatency: medianLatency(for: samples),
            firstSeen: samples.map(\.timestamp).min()!,
            lastSeen: samples.map(\.timestamp).max()!
        )
    }

    private var statisticsByPID: [UInt16: PIDStatistics] {
        statisticsCache
    }

    // MARK: - Public API

    func fastestPIDs(limit: Int = 10) -> [UInt16] {
        statisticsByPID.values
            .sorted()
            .prefix(limit)
            .map(\.pid)
    }

    func slowestPIDs(limit: Int = 10) -> [UInt16] {
        statisticsByPID.values
            .sorted(by: >)
            .prefix(limit)
            .map(\.pid)
    }

    func statistics(for pid: UInt16) -> PIDStatistics? {
        statisticsByPID[pid]
    }

    func positiveClusters() -> [PIDRange] {
        // Reserved for future clustering based on contiguous successful PID ranges.
        []
    }

    func averageLatency(around pid: UInt16) -> Double {
        let samples = telemetry.filter {
            abs(Int($0.pid) - Int(pid)) <= Self.neighborhoodRadius
        }
        guard !samples.isEmpty else {
            return 0
        }
        return averageLatency(for: samples)
    }
}
