//
//  SearchEngineFactory.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//

import Foundation
import SwiftUI

enum SearchEngineFactory {

    @AppStorage("enableTelemetryLearning")
    private static var enableTelemetryLearning = true

    @AppStorage("successWeight")
    private static var successWeight = 1000.0

    @AppStorage("latencyWeight")
    private static var latencyWeight = 1000.0

    @AppStorage("confidenceWeight")
    private static var confidenceWeight = 2.0

    @AppStorage("distanceWeight")
    private static var distanceWeight = 1.0

    // MARK: - Internal

    private static func ensureRegistered() {
        SearchEngineBootstrap.registerAll()
    }

    // MARK: - Registry Access

    private static func descriptor(
        for type: SearchEngineType
    ) -> (any SearchEngineDescriptor)? {
        ensureRegistered()
        return SearchEngineRegistry.descriptor(for: type)
    }

    // MARK: - Public API

    @MainActor
    static func engine(
        for type: SearchEngineType
    ) -> SearchEngine? {
        guard let descriptor = descriptor(for: type) else {
            return nil
        }

        return SearchEngine(descriptor: descriptor)
    }

    @MainActor
    static func make(
        type: SearchEngineType,
        start: UInt16,
        end: UInt16
    ) -> any SearchStrategy {
        guard let descriptor = descriptor(for: type) else {
            preconditionFailure("No SearchEngine registered for \(type)")
        }

        var strategy = descriptor.makeStrategy(
            start: start,
            end: end
        )

        if type == .smart,
           var smart = strategy as? SmartSearchStrategy {

            let weights = SmartSearchStrategy.ScoringWeights(
                successWeight: successWeight,
                latencyWeight: latencyWeight,
                confidenceWeight: confidenceWeight,
                distanceWeight: distanceWeight
            )

            smart = SmartSearchStrategy(
                start: start,
                end: end,
                analyzer: enableTelemetryLearning
                    ? TelemetryStore.shared.analyzer()
                    : nil,
                scoring: weights
            )

            strategy = smart
        }

        return strategy
    }
}
