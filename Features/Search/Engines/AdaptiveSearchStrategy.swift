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

    @inline(__always)
    private func outcome(for result: SearchResult) -> SearchKnowledgeBase.Outcome {
        switch result {
        case .positive:
            return .positive
        case .negative:
            return .negative
        case .noData:
            return .noData
        case .timeout:
            return .timeout
        case .unknown:
            return .unknown
        }
    }

    @inline(__always)
    private mutating func enqueueCandidates(
        _ candidates: [SearchKnowledgeBase.Candidate]
    ) {
        for candidate in candidates where !visited.contains(candidate.pid) {
            queue.enqueue(
                pid: candidate.pid,
                priority: candidate.priority
            )
        }
    }

    var isExhausted: Bool {
        queue.isEmpty && sequential > Int(end)
    }

    // MARK: - Lifecycle
    init(start: UInt16, end: UInt16) {
        precondition(start <= end)
        self.start = start
        self.end = end
        self.sequential = Int(start)
    }

    // MARK: - State
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
        let candidates = knowledge.record(
            outcome(for: result),
            for: pid
        )
        _ = knowledge.knowledge(for: pid)
        enqueueCandidates(candidates)
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
