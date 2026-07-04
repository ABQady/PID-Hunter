//
//  SearchKnowledgeBase.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//

import Foundation

/// Stores learned knowledge gathered during a scan.
struct SearchKnowledgeBase {

    enum Outcome {
        case positive
        case negative
        case noData
        case timeout
    }

    struct RegionKnowledge {
        var score: Double = 0
        var positives = 0
        var negatives = 0
        var noData = 0
        var timeouts = 0
        var averageLatency: Double = 0
        var samples = 0
    }

    struct Candidate {
        let pid: UInt16
        let priority: Double
    }

    private(set) var regions: [UInt16: RegionKnowledge] = [:]

    private static let neighborhood = -4...4

    // MARK: - Private

    @inline(__always)
    private func weight(for offset: Int) -> Double {
        max(0.0, 1.0 - (Double(abs(offset)) / 5.0))
    }

    @inline(__always)
    private func delta(for outcome: Outcome) -> Double {
        switch outcome {
        case .positive:
            return 10
        case .negative:
            return 2
        case .noData:
            return -3
        case .timeout:
            return -1
        }
    }

    mutating func reset() {
        regions.removeAll(keepingCapacity: true)
    }

    /// Updates learned knowledge and returns nearby candidates ordered by priority.
    @discardableResult
    mutating func record(_ outcome: Outcome, for pid: UInt16) -> [Candidate] {
        var knowledge = regions[pid] ?? RegionKnowledge()

        switch outcome {
        case .positive:
            knowledge.positives += 1
        case .negative:
            knowledge.negatives += 1
        case .noData:
            knowledge.noData += 1
        case .timeout:
            knowledge.timeouts += 1
        }

        regions[pid] = knowledge

        return adjustRegion(
            around: pid,
            delta: delta(for: outcome)
        )
    }

    func score(for pid: UInt16) -> Double {
        regions[pid]?.score ?? 0
    }

    func knowledge(for pid: UInt16) -> RegionKnowledge? {
        regions[pid]
    }

    private mutating func adjustRegion(around pid: UInt16, delta: Double) -> [Candidate] {
        var candidates: [Candidate] = []
        for offset in Self.neighborhood {
            let value = Int(pid) + offset
            guard (0...0xFFFF).contains(value) else { continue }

            let neighbor = UInt16(value)
            let weight = weight(for: offset)
            var knowledge = regions[neighbor] ?? RegionKnowledge()
            knowledge.score += delta * weight
            regions[neighbor] = knowledge
            candidates.append(
                Candidate(
                    pid: neighbor,
                    priority: knowledge.score
                )
            )
        }
        return candidates.sorted(by: { $0.priority > $1.priority })
    }
}
