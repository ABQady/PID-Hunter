//
//  PartialFrameRetryEngine.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 12/07/2026.
//

import Foundation

enum PartialFrameRetryOutcome {

    case success(
        response: ELMResponse,
        classification: SearchResult,
        latency: Double
    )

    case timeout

    case connectionLost
}

struct PartialFrameRetryResult {

    let frame: PartialFrame
    let outcome: PartialFrameRetryOutcome
}

/// Executes retry requests only. The scanner owns retry eligibility, state changes,
/// profile learning, and persistence.
struct PartialFrameRetryEngine {

    private var maximumAttempts: Int {
        let value = UserDefaults.standard.integer(
            forKey: "partialFrameRetryCount"
        )

        return value == 0 ? 3 : value
    }

    private func shouldRetry(
        _ frame: PartialFrame
    ) -> Bool {
        frame.resolution == .pending &&
        frame.attempts < maximumAttempts
    }

    private func pendingFrames(
        from frames: [PartialFrame]
    ) -> [PartialFrame] {
        frames.filter(shouldRetry)
    }

    func retryPendingFrames(
        using executor: RequestExecutor,
        frames: [PartialFrame],
        makeContext: (PartialFrame) -> RequestContext,
        timeout: Double
    ) async -> [PartialFrameRetryResult] {

        var retryResults: [PartialFrameRetryResult] = []

        for frame in pendingFrames(from: frames) {

            let execution = await executor.execute(
                request: frame.request,
                context: makeContext(frame),
                timeout: timeout
            )

            switch execution {

            case .success(
                let response,
                let classification,
                let latency
            ):

                retryResults.append(
                    PartialFrameRetryResult(
                        frame: frame,
                        outcome: .success(
                            response: response,
                            classification: classification,
                            latency: latency
                        )
                    )
                )

            case .timeout:

                retryResults.append(
                    PartialFrameRetryResult(
                        frame: frame,
                        outcome: .timeout
                    )
                )

            case .connectionLost:

                retryResults.append(
                    PartialFrameRetryResult(
                        frame: frame,
                        outcome: .connectionLost
                    )
                )
            }

            Logger.shared.debug(
                "Partial retry \(frame.request) -> \(execution)"
            )
        }

        return retryResults
    }
}
