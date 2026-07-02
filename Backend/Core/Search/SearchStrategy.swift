//
//  SearchStrategy.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//

import Foundation

/// Defines how the scanner chooses the next PID and learns from scan results.
protocol SearchStrategy {

    // MARK: - Lifecycle

    mutating func reset()

    // MARK: - PID Selection

    /// Returns the next PID to scan, or nil when the strategy is exhausted.
    mutating func nextPID() -> UInt16?

    // MARK: - Feedback

    // TODO: Future SearchResult revisions may include confidence, payload quality and transport metadata.
    /// Provides a classified scan result so search strategies can update their learning model.
    mutating func registerResult(
        pid: UInt16,
        result: SearchResult,
        latency: Double
    )
    
    // MARK: - Navigation

    /// Moves the strategy to a specific PID position.
    mutating func seek(to pid: UInt16)

}
