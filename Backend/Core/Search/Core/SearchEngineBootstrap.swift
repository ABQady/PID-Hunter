//
//  SearchEngineBootstrap.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//

import Foundation

enum SearchEngineBootstrap {

    private static var isBootstrapped = false

    private static let experimentalEngines: [(SearchEngineType, String, String)] = [
        (.ucb, "UCB", "function"),
        (.thompson, "Thompson", "chart.xyaxis.line"),
        (.heatMap, "Heat Map", "flame"),
        (.cluster, "Cluster", "square.grid.3x3.fill"),
        (.hybrid, "Hybrid", "point.3.connected.trianglepath.dotted")
    ]
    
    // MARK: - Public API

    // MARK: - Bootstrap
    static func registerAll() {
        guard !isBootstrapped else {
            return
        }
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

    @inline(__always)
    private static func registerExperimental(
        _ type: SearchEngineType,
        name: String,
        icon: String
    ) {
        SearchEngineRegistry.register(
            ExperimentalAdaptiveDescriptor(
                type: type,
                displayName: name,
                description: "Experimental engine backed by Adaptive."
            )
        )
    }

    // MARK: - Experimental Engines

    private static func registerExperimentalEngines() {
        for (type, name, icon) in experimentalEngines {
            registerExperimental(type, name: name, icon: icon)
        }
    }
}
