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

    private static var smartScoringWeights: SmartSearchStrategy.ScoringWeights {
        .init(
            successWeight: successWeight,
            latencyWeight: latencyWeight,
            confidenceWeight: confidenceWeight,
            distanceWeight: distanceWeight
        )
    }

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

    // MARK: - Strategy Creation

    @MainActor
    private static func makeStrategy(
        descriptor: any SearchEngineDescriptor,
        type: SearchEngineType,
        start: UInt16,
        end: UInt16
    ) -> any SearchStrategy {
        if type == .smart {
            return SmartSearchStrategy(
                start: start,
                end: end,
                analyzer: enableTelemetryLearning
                    ? TelemetryStore.shared.analyzer()
                    : nil,
                scoring: smartScoringWeights
            )
        }

        return descriptor.makeStrategy(
            start: start,
            end: end
        )
    }

    // MARK: - Factory

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

        let strategy = makeStrategy(
            descriptor: descriptor,
            type: type,
            start: start,
            end: end
        )

        Logger.shared.info(
            "Factory created \(strategy.engineType)"
        )

        return strategy
    }
}
