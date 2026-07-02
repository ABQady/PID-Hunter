//
//  SearchStrategy.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//

import Foundation

protocol SearchStrategy {

    // MARK: - Lifecycle

    mutating func reset()

    // MARK: - PID Selection

    /// Returns the next PID to scan, or nil when the strategy is exhausted.
    mutating func nextPID() -> UInt16?

    // MARK: - Feedback

    /// Provides scan feedback so adaptive strategies can update their state.
    mutating func registerResult(
        pid: UInt16,
        success: Bool,
        response: String,
        latency: Double
    )
    
    // MARK: - Navigation

    /// Moves the strategy to a specific PID position.
    mutating func seek(to pid: UInt16)

}
