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
    case unknown(ELMResponse)
}

struct ResponseClassifier {

    func classify(_ response: ELMResponse) -> SearchResult {
        let text = response.raw.uppercased()

        if text.contains("NO DATA") {
            return .noData
        }

        switch response.type {

        case .atResponse:
            return .positive(response)

        case .negative:
            return .negative(response)

        case .mode01,
             .mode21,
             .mode22:
            return .positive(response)

        case .unknown,
             .unknownFrame:
            return .unknown(response)

        default:
            return .unknown(response)
        }
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
    private let transport = ELM327.shared
    private let telemetry = TelemetryStore.shared

    @inline(__always)
    private func recordTelemetry(
        context: RequestContext,
        result: ELM327.ELMRequestResult,
        classification: SearchResult
    ) {
        telemetry.record(
            RequestTelemetry(
                timestamp: Date(),
                mode: context.mode,
                pid: context.pid,
                header: context.header,
                latency: result.latency,
                response: result.response,
                classification: classification,
                retryCount: context.retryCount,
                searchEngine: context.searchEngine
            )
        )
    }

    /// Sends a single OBD request and converts transport errors into scanner-friendly results.
    func execute(
        request: String,
        context: RequestContext,
        timeout: Double
    ) async -> RequestResult {

        Logger.shared.debug("Executing request: \(request)")

        guard BluetoothManager.shared.isConnected else {
            return .connectionLost
        }

        do {
            let result = try await transport.request(
                command: request,
                timeout: .seconds(timeout)
            )

            let searchResult = classifier.classify(result.response)
            Logger.shared.debug("Response classified as: \(searchResult)")

            recordTelemetry(
                context: context,
                result: result,
                classification: searchResult
            )

            Logger.shared.debug("Request succeeded: \(request) | latency=\(result.latency)s")
            return .success(
                response: result.response,
                latency: result.latency
            )

        } catch BluetoothManager.BluetoothError.timeout {
            Logger.shared.debug("Request timed out: \(request)")
            return .timeout

        } catch {
            Logger.shared.error("Request failed: \(error.localizedDescription)")
            return .connectionLost
        }
    }

    func classify(_ response: ELMResponse) -> SearchResult {
        classifier.classify(response)
    }
}
