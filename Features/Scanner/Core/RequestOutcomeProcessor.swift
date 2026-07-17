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

@MainActor
final class RequestOutcomeProcessor {

    static let shared = RequestOutcomeProcessor()

    private init() {}

    @discardableResult
    private func recordOutcome(
        response: ELMResponse,
        latency: TimeInterval,
        mode: OBDMode,
        requestHeader: String,
        request: String,
        source: RecordSource,
        logAction: () -> Void,
        shouldPersist: Bool,
        consecutiveTimeouts: inout Int
    ) -> RequestOutcome {
        // Reset timeout state.
        consecutiveTimeouts = 0

        // Persist the discovery into the active bike profile.
        BikeProfileManager.shared.record(
            header: requestHeader,
            mode: mode,
            request: request,
            response: response,
            latency: latency,
            source: source
        )

        // Emit outcome-specific logging.
        logAction()

        // Return the scanner-facing processing result.
        return .success(
            ScanProcessingResult(
                shouldPersist: shouldPersist
            )
        )
    }

    @discardableResult
    func recordRetryPositive(
        response: ELMResponse,
        classification: SearchResult,
        latency: TimeInterval,
        mode: OBDMode,
        requestHeader: String,
        request: String,
        consecutiveTimeouts: inout Int
    ) -> RequestOutcome {
        return recordOutcome(
            response: response,
            latency: latency,
            mode: mode,
            requestHeader: requestHeader,
            request: request,
            source: .retryPositive,
            logAction: {
                Logger.shared.success(
                    "🟢 Retry Positive | \(mode.rawValue) | \(request) | \(Int(latency * 1000)) ms"
                )
            },
            shouldPersist: classification.shouldPersist,
            consecutiveTimeouts: &consecutiveTimeouts
        )
    }
    
    // MARK: - Success

    @discardableResult
    func handleSuccess(
        response: ELMResponse,
        classification: SearchResult,
        latency: TimeInterval,
        mode: OBDMode,
        request: String,
        requestHeader: String,
        consecutiveTimeouts: inout Int
    ) -> RequestOutcome {
        return recordOutcome(
            response: response,
            latency: latency,
            mode: mode,
            requestHeader: requestHeader,
            request: request,
            source: .discovery,
            logAction: {
                Logger.shared.verbose(.outcome,
                    """
📦 Outcome
Classification : \(classification)
Persist        : \(classification.shouldPersist)
Request Header : \(requestHeader)
Response Header: \(response.header ?? "nil")
Request        : \(request)
Response PID   : \(response.pid.map { String(format: "%04X", $0) } ?? "nil")
Latency        : \(Int(latency * 1000)) ms
Raw Response   : \(response.raw)
"""
                )
            },
            shouldPersist: classification.shouldPersist,
            consecutiveTimeouts: &consecutiveTimeouts
        )
    }

    // MARK: - Confirmed Negative

    @discardableResult
    func recordConfirmedNegative(
        response: ELMResponse,
        classification: SearchResult,
        latency: TimeInterval,
        mode: OBDMode,
        requestHeader: String,
        request: String,
        consecutiveTimeouts: inout Int
    ) -> RequestOutcome {
        return recordOutcome(
            response: response,
            latency: latency,
            mode: mode,
            requestHeader: requestHeader,
            request: request,
            source: .confirmedNegative,
            logAction: {
                Logger.shared.verbose(.outcome,
                    "🔴 Confirmed Negative | \(mode.rawValue) | \(request) | \(classification) | \(Int(latency * 1000)) ms"
                )
            },
            shouldPersist: false,
            consecutiveTimeouts: &consecutiveTimeouts
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
