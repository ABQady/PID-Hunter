//
//  RequestExecutor.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//
import Foundation

// MARK: - Request Result

// TODO: Migrate downstream consumers to use RequestContext instead of reconstructing
// request metadata from ELMResponse where possible.
enum RequestResult {
    case success(
        context: RequestContext,
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

/// Immutable metadata describing the original scan request.
/// This context is the source of truth throughout the scan pipeline.
/// Transport responses may differ (for example response header vs. request header),
/// so downstream components must prefer values from RequestContext whenever they
/// refer to the original request.
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
        response: ELMResponse,
        latency: TimeInterval,
        classification: SearchResult
    ) {
        Logger.shared.verbose(
            """
📡 Telemetry
Mode           : \(context.mode.rawValue)
PID            : \(String(format: "%04X", context.pid))
Request Header : \(context.header)
Retry          : \(context.retryCount)
Engine         : \(context.searchEngine)
Response Header: \(response.header ?? "nil")
Response PID   : \(response.pid.map { String(format: "%04X", $0) } ?? "nil")
Classification : \(classification)
Latency        : \(String(format: "%.3f", latency)) s
"""
        )
        telemetry.record(
            RequestTelemetry(
                timestamp: Date(),
                mode: context.mode,
                pid: context.pid,
                header: context.header,
                latency: latency,
                response: response,
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
            let transportResult = try await transport.request(
                command: request,
                timeout: .seconds(timeout)
            )

            let classification = await classifier.classify(transportResult.response)
            Logger.shared.verbose("""
Request Classification
REQUEST = \(request)
TYPE    = \(transportResult.response.type)
RESULT  = \(classification)
LATENCY = \(String(format: "%.3f", transportResult.latency)) s
""")
            recordTelemetry(
                context: context,
                response: transportResult.response,
                latency: transportResult.latency,
                classification: classification
            )

            Logger.shared.debug(
                "Completed → \(request) (\(String(format: "%.3f", transportResult.latency)) s)"
            )
            return .success(
                context: context,
                response: transportResult.response,
                classification: classification,
                latency: transportResult.latency
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
