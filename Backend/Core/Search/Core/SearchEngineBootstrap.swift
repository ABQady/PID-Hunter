//
//  SearchEngineBootstrap.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//

import Foundation

enum SearchEngineBootstrap {

    private static var hasRegistered = false

    // MARK: - Public API

    static func registerAll() {
        guard !hasRegistered else { return }
        hasRegistered = true

        registerCoreEngines()
        registerExperimentalEngines()
    }

    // MARK: - Core Engines

    private static func registerCoreEngines() {
        SearchEngineFactory.register(SequentialSearchEngineDescriptor())
        SearchEngineFactory.register(SmartSearchEngineDescriptor())
        SearchEngineFactory.register(AdaptiveSearchEngineDescriptor())
    }

    // MARK: - Experimental Engines

    private static func registerExperimentalEngines() {
        SearchEngineFactory.register(ExperimentalAdaptiveDescriptor(type: .ucb, displayName: "UCB", description: "Experimental engine backed by Adaptive.", icon: "function"))
        SearchEngineFactory.register(ExperimentalAdaptiveDescriptor(type: .thompson, displayName: "Thompson", description: "Experimental engine backed by Adaptive.", icon: "chart.xyaxis.line"))
        SearchEngineFactory.register(ExperimentalAdaptiveDescriptor(type: .heatMap, displayName: "Heat Map", description: "Experimental engine backed by Adaptive.", icon: "flame"))
        SearchEngineFactory.register(ExperimentalAdaptiveDescriptor(type: .cluster, displayName: "Cluster", description: "Experimental engine backed by Adaptive.", icon: "square.grid.3x3.fill"))
        SearchEngineFactory.register(ExperimentalAdaptiveDescriptor(type: .hybrid, displayName: "Hybrid", description: "Experimental engine backed by Adaptive.", icon: "point.3.connected.trianglepath.dotted"))
    }
}
