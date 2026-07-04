//
//  SearchContext.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//

import Foundation

struct SearchContext {

    // MARK: - Configuration

    let configuration: SearchConfiguration

    // MARK: - Convenience

    @inline(__always)
    var startPID: UInt16 { configuration.startPID }
    @inline(__always)
    var endPID: UInt16 { configuration.endPID }
    @inline(__always)
    var mode: String { configuration.mode }
    @inline(__always)
    var header: String { configuration.header }

    // MARK: - Shared State

    var knowledge = SearchKnowledgeBase()
    var queue = PIDQueue()
    var statistics = SearchStatistics()

    // MARK: - Runtime

    var visited: Set<UInt16> = []
    var discovered: Set<UInt16> = []

    @inline(__always)
    var remainingCount: Int {
        Int(endPID) - Int(startPID) + 1 - visited.count
    }

    @inline(__always)
    mutating func resetRuntimeState() {
        queue.clear()
        visited.removeAll(keepingCapacity: true)
        discovered.removeAll(keepingCapacity: true)
        statistics.reset()
    }

    // MARK: - Lifecycle

    init(configuration: SearchConfiguration) {
        self.configuration = configuration
    }
}
