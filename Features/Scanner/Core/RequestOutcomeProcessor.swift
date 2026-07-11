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
    let profileUpdated: Bool
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

@MainActor
final class RequestOutcomeProcessor {

    static let shared = RequestOutcomeProcessor()

    private init() {}

    // MARK: - Success

    @discardableResult
    func handleSuccess(
        response: ELMResponse,
        classification: SearchResult,
        latency: TimeInterval,
        mode: OBDMode,
        request: String,
        consecutiveTimeouts: inout Int
    ) -> RequestOutcome {

        consecutiveTimeouts = 0
        let shouldPersist = classification.shouldPersist
        BikeProfileManager.shared.record(
            mode: mode,
            request: request,
            response: response,
            latency: latency
        )

        Logger.shared.verbose(
            "📦 Outcome → \(classification) | Persist=\(shouldPersist) | \(request) | \(Int(latency * 1000)) ms"
        )
        return .success(
            ScanProcessingResult(
                shouldPersist: shouldPersist,
                profileUpdated: true
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
    func flushProfile() {
        BikeProfileManager.shared.flush()
    }
}
