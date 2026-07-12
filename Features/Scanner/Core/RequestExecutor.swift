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
        classification: SearchResult,
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
    case partialFrame(ELMResponse)
    case timeout
    case unknown(ELMResponse)
    case adapter(ELMResponse)
}

struct ResponseClassifier {

    func classify(_ response: ELMResponse) async -> SearchResult {
        
        switch response.type {

        case .positive:
            // A response classified as positive may still be an incomplete frame
            // (for example, only the echoed header without a service byte/payload).
            // Treat those as partial frames so they can be retried later instead of
            // being promoted to positive or discarded as negative.
            if response.raw == "83F111" {
                return .partialFrame(response)
            }
            return .positive(response)
            
        case .partialFrame:
            return .partialFrame(response)
            
        case .negative:
            return .negative(response)

        case .noData:
            return .noData

        case .atResponse,
             .searching,
             .stopped:
            return .adapter(response)

        case .busError,
             .unableToConnect,
             .unknown:
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

        Logger.shared.debug("Request → \(request)")

        guard BluetoothManager.shared.isConnected else {
            return .connectionLost
        }

        do {
            let result = try await transport.request(
                command: request,
                timeout: .seconds(timeout)
            )

            let searchResult = await classifier.classify(result.response)
            Logger.shared.verbose("""
Request Classification
REQUEST = \(request)
TYPE    = \(result.response.type)
RESULT  = \(searchResult)
LATENCY = \(String(format: "%.3f", result.latency)) s
""")
            recordTelemetry(
                context: context,
                result: result,
                classification: searchResult
            )

            Logger.shared.debug(
                "Completed → \(request) (\(String(format: "%.3f", result.latency)) s)"
            )
            return .success(
                response: result.response,
                classification: searchResult,
                latency: result.latency
            )

        } catch BluetoothManager.BluetoothError.timeout {
            Logger.shared.debug("Timeout → \(request)")
            return .timeout

        } catch {
            Logger.shared.error("Request failed: \(error.localizedDescription)")
            return .connectionLost
        }
    }
}
extension SearchResult {

    var shouldPersist: Bool {
        switch self {
        case .positive:
            return true
        default:
            return false
        }
    }

    var isPositive: Bool {
        switch self {
        case .positive:
            return true
        default:
            return false
        }
    }
}
