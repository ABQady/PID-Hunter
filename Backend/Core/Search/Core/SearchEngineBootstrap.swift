//
//  SearchEngineBootstrap.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//

import Foundation

enum SearchEngineBootstrap {

    private static var isBootstrapped = false
    
    // MARK: - Public API

    static func registerAll() {
        guard !isBootstrapped else { return }
        isBootstrapped = true

        registerCoreEngines()
        registerExperimentalEngines()
    }

    // MARK: - Core Engines

    private static func registerCoreEngines() {
        SearchEngineRegistry.register(SequentialSearchEngineDescriptor())
        SearchEngineRegistry.register(SmartSearchEngineDescriptor())
        SearchEngineRegistry.register(AdaptiveSearchEngineDescriptor())
    }

    private static func registerExperimental(
        _ type: SearchEngineType,
        name: String,
        icon: String
    ) {
        SearchEngineRegistry.register(
            ExperimentalAdaptiveDescriptor(
                type: type,
                displayName: name,
                description: "Experimental engine backed by Adaptive.",
                icon: icon
            )
        )
    }

    // MARK: - Experimental Engines

    private static func registerExperimentalEngines() {
        registerExperimental(.ucb, name: "UCB", icon: "function")
        registerExperimental(.thompson, name: "Thompson", icon: "chart.xyaxis.line")
        registerExperimental(.heatMap, name: "Heat Map", icon: "flame")
        registerExperimental(.cluster, name: "Cluster", icon: "square.grid.3x3.fill")
        registerExperimental(.hybrid, name: "Hybrid", icon: "point.3.connected.trianglepath.dotted")
    }
}
