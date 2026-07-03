//
//  SearchConfiguration.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//

import Foundation

struct SearchConfiguration: Sendable {

    // MARK: - Scan Range

    let startPID: UInt16
    let endPID: UInt16

    // MARK: - ECU

    let mode: String
    let header: String

    // MARK: - Timing

    let requestDelay: TimeInterval
    let timeout: TimeInterval

    // MARK: - Initialization

    init(
        startPID: UInt16,
        endPID: UInt16,
        mode: String,
        header: String,
        requestDelay: TimeInterval = 0,
        timeout: TimeInterval = 1.0
    ) {
        precondition(startPID <= endPID, "startPID must not exceed endPID")

        self.startPID = startPID
        self.endPID = endPID
        self.mode = mode
        self.header = header
        self.requestDelay = requestDelay
        self.timeout = timeout
    }
}
