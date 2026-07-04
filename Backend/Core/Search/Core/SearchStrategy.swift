//
//  SearchStrategy.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//

import Foundation

/// Defines how the scanner chooses the next PID and learns from scan results.
protocol SearchStrategy {
    // MARK: - Identity

    /// Identifies the concrete search engine for telemetry and analytics.
    var engineType: SearchEngineType { get }

    // MARK: - Lifecycle

    mutating func reset()

    // MARK: - PID Selection

    /// Returns the next PID to scan, or nil when the strategy is exhausted.
    mutating func nextPID() -> UInt16?

    /// Indicates whether the strategy has exhausted its search space.
    var isExhausted: Bool { get }

    // MARK: - Feedback

    /// Future revisions may extend SearchResult with confidence,
    /// payload quality, transport metadata and timing statistics
    /// without changing this protocol.
    mutating func registerResult(
        pid: UInt16,
        result: SearchResult,
        latency: Double
    )
    
    // MARK: - Navigation

    /// Repositions the search cursor without resetting any learned knowledge.
    /// Implementations should preserve scoring, telemetry and adaptive state,
    /// changing only the next PID that will be produced.
    mutating func seek(to pid: UInt16)

}
