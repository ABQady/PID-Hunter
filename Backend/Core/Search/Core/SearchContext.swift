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

    var startPID: UInt16 { configuration.startPID }
    var endPID: UInt16 { configuration.endPID }
    var mode: String { configuration.mode }
    var header: String { configuration.header }

    // MARK: - Shared State

    var knowledge = SearchKnowledgeBase()
    var queue = PIDQueue()
    var statistics = SearchStatistics()

    // MARK: - Runtime

    var visited: Set<UInt16> = []
    var discovered: Set<UInt16> = []

    init(configuration: SearchConfiguration) {
        self.configuration = configuration
    }
}
