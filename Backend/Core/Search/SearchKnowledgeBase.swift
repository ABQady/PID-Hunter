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

        let delta: Double

        switch outcome {
        case .positive:
            delta = 10
        case .negative:
            delta = 2
        case .noData:
            delta = -3
        case .timeout:
            delta = -1
        }
        return adjustRegion(around: pid, delta: delta)
    }

    func score(for pid: UInt16) -> Double {
        regions[pid]?.score ?? 0
    }

    func knowledge(for pid: UInt16) -> RegionKnowledge? {
        regions[pid]
    }

    // MARK: - Private

    private mutating func adjustRegion(around pid: UInt16, delta: Double) -> [Candidate] {
        var candidates: [Candidate] = []
        for offset in -4...4 {
            let value = Int(pid) + offset
            guard (0...0xFFFF).contains(value) else { continue }

            let neighbor = UInt16(value)
            let weight = max(0.0, 1.0 - (Double(abs(offset)) / 5.0))
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
        return candidates.sorted { lhs, rhs in
            lhs.priority > rhs.priority
        }
    }
}
