//
//  RequestOutcomeProcessor.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 10/07/2026.
//

import Foundation

/// Represents the result of processing a successful scan response.
struct ScanProcessingResult {
    let shouldPersist: Bool
}

/// Represents the result of processing a timeout event during scanning.
struct TimeoutProcessingResult {
    let consecutiveTimeouts: Int
    let shouldAbortScan: Bool
}

enum RequestOutcome {
    case success(ScanProcessingResult)
    case timeout(TimeoutProcessingResult)
}

final class RequestOutcomeProcessor {

    static let shared = RequestOutcomeProcessor()

    private init() {}

    // MARK: - Success

    @discardableResult
    func handleSuccess(
        response: ELMResponse,
        classification: SearchResult,
        latency: TimeInterval,
        header: String,
        mode: OBDMode,
        request: String,
        pid: UInt16,
        consecutiveTimeouts: inout Int
    ) -> RequestOutcome {

        consecutiveTimeouts = 0

        return .success(
            ScanProcessingResult(
                shouldPersist: classification.shouldPersist
            )
        )
    }

    // MARK: - Timeout

    func handleTimeout(
        timeout: TimeInterval,
        consecutiveTimeouts: inout Int,
        maxConsecutiveTimeouts: Int
    ) -> RequestOutcome {

        consecutiveTimeouts += 1

        return .timeout(
            TimeoutProcessingResult(
                consecutiveTimeouts: consecutiveTimeouts,
                shouldAbortScan: consecutiveTimeouts >= maxConsecutiveTimeouts
            )
        )
    }
}
