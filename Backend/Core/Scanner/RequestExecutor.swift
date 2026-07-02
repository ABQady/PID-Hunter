//
//  RequestExecutor.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//
import Foundation

// MARK: - Request Result

enum RequestResult {
    case success(ELMResponse)
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

// MARK: - Request Executor

@MainActor
final class RequestExecutor {

    // TODO: Support retries and request classification without exposing BluetoothManager.

    private let classifier = ResponseClassifier()

    /// Sends a single OBD request and converts transport errors into scanner-friendly results.
    func execute(
        request: String,
        timeout: Double
    ) async -> RequestResult {

        guard BluetoothManager.shared.isConnected else {
            return .connectionLost
        }

        do {
            let response = try await BluetoothManager.shared.sendAndWait(
                request,
                timeout: .seconds(timeout)
            )

            return .success(response)

        } catch BluetoothManager.BluetoothError.timeout {
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
