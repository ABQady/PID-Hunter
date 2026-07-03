//
//  AdaptiveSearchStrategy.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//

import Foundation

struct AdaptiveSearchStrategy: SearchStrategy {

    let engineType: SearchEngineType = .adaptive
    private let start: UInt16
    private let end: UInt16

    private var sequential: Int
    private var visited: Set<UInt16> = []

    private var knowledge = SearchKnowledgeBase()
    private var queue = PriorityPIDQueue()

    var isExhausted: Bool {
        queue.isEmpty && sequential > Int(end)
    }

    init(start: UInt16, end: UInt16) {
        precondition(start <= end)
        self.start = start
        self.end = end
        self.sequential = Int(start)
    }

    mutating func reset() {
        sequential = Int(start)
        visited.removeAll(keepingCapacity: true)
        knowledge.reset()
        queue.clear()
    }

    // MARK: - PID Selection

    mutating func nextPID() -> UInt16? {

        while let pid = queue.dequeue() {
            guard visited.insert(pid).inserted else { continue }
            return pid
        }

        while sequential <= Int(end) {
            let pid = UInt16(sequential)
            sequential += 1
            guard visited.insert(pid).inserted else { continue }
            return pid
        }

        return nil
    }

    // MARK: - Learning
    // TODO: Extend SearchResult with richer metadata so latency and payload quality influence learning.
    mutating func registerResult(
        pid: UInt16,
        result: SearchResult,
        latency: Double
    ) {
        let outcome: SearchKnowledgeBase.Outcome

        switch result {
        case .positive:
            outcome = .positive
        case .negative:
            outcome = .negative
        case .noData:
            outcome = .noData
        case .timeout:
            outcome = .timeout
        }

        let candidates = knowledge.record(outcome, for: pid)

        if let info = knowledge.knowledge(for: pid),
           info.samples > 0,
           latency > 0 {
            // Reserved for future latency-aware scoring.
        }

        for candidate in candidates {
            guard !visited.contains(candidate.pid) else { continue }

            queue.enqueue(
                pid: candidate.pid,
                priority: candidate.priority
            )
        }

        _ = latency
    }

    // MARK: - Navigation
    mutating func seek(to pid: UInt16) {
        sequential = min(max(Int(pid), Int(start)), Int(end) + 1)
        visited.removeAll(keepingCapacity: true)
        knowledge.reset()
        queue.clear()
    }
}
