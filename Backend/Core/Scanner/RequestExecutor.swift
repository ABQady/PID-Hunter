//
//  RequestExecutor.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//
import Foundation

// MARK: - Request Result

enum RequestResult {
    case success(
        response: ELMResponse,
        latency: TimeInterval
    )
    case timeout
    case connectionLost
}

// MARK: - Response Classification

enum SearchResult {
    case positive(ELMResponse)
    case noData
    case negative(ELMResponse)
    case timeout
}

struct ResponseClassifier {

    func classify(_ response: ELMResponse) -> SearchResult {
        let text = response.raw.uppercased()

        if text.contains("NO DATA") {
            return .noData
        }

        if text.contains("7F") {
            return .negative(response)
        }

        return .positive(response)
    }
}

struct RequestContext {
    let mode: OBDMode
    let pid: UInt16
    let header: String
    let retryCount: Int
    let searchEngine: SearchEngineType
}

// MARK: - Request Executor

@MainActor
final class RequestExecutor {

    // TODO:
    // - Inject an OBDTransport implementation.
    // - Record SearchStatistics automatically.
    // - Support retry policies.
    // - Support request tracing.

    private let classifier = ResponseClassifier()

    private(set) var statistics: SearchStatistics
    
    init(statistics: SearchStatistics = .init()) {
        self.statistics = statistics
    }
    
    /// Sends a single OBD request and converts transport errors into scanner-friendly results.
    func execute(
        request: String,
        context: RequestContext,
        timeout: Double
    ) async -> RequestResult {

        statistics.recordRequest()

        guard BluetoothManager.shared.isConnected else {
            return .connectionLost
        }

        do {
            let result = try await ELM327.shared.request(
                command: request,
                timeout: .seconds(timeout)
            )

            statistics.recordSuccess(latency: result.latency)

            let searchResult = classifier.classify(result.response)

            TelemetryStore.shared.record(
                RequestTelemetry(
                    timestamp: Date(),
                    mode: context.mode,
                    pid: context.pid,
                    header: context.header,
                    latency: result.latency,
                    response: result.response,
                    classification: searchResult,
                    retryCount: context.retryCount,
                    searchEngine: context.searchEngine
                )
            )

            return .success(
                response: result.response,
                latency: result.latency
            )

        } catch BluetoothManager.BluetoothError.timeout {
            statistics.recordFailure()
            return .timeout

        } catch {
            statistics.recordFailure()
            Logger.shared.error("Request failed: \(error.localizedDescription)")
            return .connectionLost
        }
    }

    func classify(_ response: ELMResponse) -> SearchResult {
        classifier.classify(response)
    }

    func resetStatistics() {
        statistics.reset()
    }
}
