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
    private var cachedAnalyzer: TelemetryAnalyzer?
    private var analyzerDirty = true

    @inline(__always)
    private func invalidateAnalyzer() {
        analyzerDirty = true
        cachedAnalyzer = nil
    }

    // MARK: - Recording
    func record(_ request: RequestTelemetry) {
        requests.append(request)
        invalidateAnalyzer()
    }

    func clear() {
        requests.removeAll(keepingCapacity: true)
        invalidateAnalyzer()
    }

    // MARK: - Analysis
    func analyzer() -> TelemetryAnalyzer {
        if analyzerDirty || cachedAnalyzer == nil {
            cachedAnalyzer = TelemetryAnalyzer(telemetry: requests)
            analyzerDirty = false
        }

        return cachedAnalyzer!
    }
}
