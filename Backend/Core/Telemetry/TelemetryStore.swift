//
//  TelemetryStore.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 03/07/2026.
//
import Foundation
import SwiftUI

@MainActor
final class TelemetryStore: ObservableObject {

    static let shared = TelemetryStore()

    @Published private(set) var requests: [RequestTelemetry] = []

    /// Read-only view used by analytics and search strategies.
    var telemetry: [RequestTelemetry] {
        requests
    }

    func record(_ request: RequestTelemetry) {
        requests.append(request)
    }

    func clear() {
        requests.removeAll()
    }

    func analyzer() -> TelemetryAnalyzer {
        TelemetryAnalyzer(telemetry: requests)
    }
}
