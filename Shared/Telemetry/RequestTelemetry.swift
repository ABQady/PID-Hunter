//
//  RequestTelemetry.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 03/07/2026.
//
import Foundation

struct RequestTelemetry: Identifiable {

    // MARK: - Identity

    let id = UUID()

    // MARK: - Request

    let timestamp: Date

    let mode: OBDMode

    let pid: UInt16

    let header: String

    // MARK: - Response

    let latency: TimeInterval

    let response: ELMResponse

    let classification: SearchResult

    let retryCount: Int

    let searchEngine: SearchEngineType

    // MARK: - Derived Values

    @inline(__always)
    var isSuccessful: Bool {
        if case .positive = classification {
            return true
        }
        return false
    }

    @inline(__always)
    var requestKey: String {
        "\(mode.rawValue):\(String(format: "%04X", pid))@\(header)"
    }

}
