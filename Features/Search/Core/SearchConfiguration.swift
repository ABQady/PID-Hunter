//
//  SearchConfiguration.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//

import Foundation

struct SearchConfiguration: Sendable {

    // MARK: - Defaults

    static let defaultTimeout: TimeInterval = 1.0
    static let defaultRequestDelay: TimeInterval = 0

    // MARK: - Scan Range

    let startPID: UInt16
    let endPID: UInt16

    // MARK: - ECU

    let mode: String
    let header: String

    // MARK: - Timing

    let requestDelay: TimeInterval
    let timeout: TimeInterval

    // MARK: - Derived Values

    @inline(__always)
    var pidCount: Int {
        Int(endPID) - Int(startPID) + 1
    }

    // MARK: - Initialization

    init(
        startPID: UInt16,
        endPID: UInt16,
        mode: String,
        header: String,
        requestDelay: TimeInterval = Self.defaultRequestDelay,
        timeout: TimeInterval = Self.defaultTimeout
    ) {
        precondition(startPID <= endPID, "startPID must not exceed endPID")
        precondition(requestDelay >= 0, "requestDelay must not be negative")
        precondition(timeout > 0, "timeout must be greater than zero")

        self.startPID = startPID
        self.endPID = endPID
        self.mode = mode
        self.header = header
        self.requestDelay = requestDelay
        self.timeout = timeout
    }
}
