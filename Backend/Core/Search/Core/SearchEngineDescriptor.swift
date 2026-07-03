//
//  SearchEngineDescriptor.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//

import Foundation

protocol SearchEngineDescriptor {
    // MARK: - Identity
    var type: SearchEngineType { get }
    var displayName: String { get }
    var description: String { get }
    var icon: String { get }
    var supportsBenchmark: Bool { get }

    // MARK: - Factory
    func makeStrategy(
        start: UInt16,
        end: UInt16
    ) -> any SearchStrategy
}

extension SearchEngineDescriptor {
    @inline(__always)
    var supportsBenchmark: Bool { true }
}

private extension SearchEngineType {
    var defaultIcon: String {
        switch self {
        case .sequential: return "list.number"
        case .smart: return "brain"
        case .adaptive: return "sparkles"
        case .ucb: return "chart.line.uptrend.xyaxis"
        case .thompson: return "dice"
        case .heatMap: return "flame"
        case .cluster: return "circle.grid.2x2"
        case .hybrid: return "square.stack.3d.up"
        }
    }
}

// MARK: - Built-in Engines
struct SequentialSearchEngineDescriptor: SearchEngineDescriptor {
    let type: SearchEngineType = .sequential
    let displayName = "Sequential"
    let description = "Scans PIDs sequentially."
    let icon = "list.number"

    func makeStrategy(start: UInt16, end: UInt16) -> any SearchStrategy {
        SequentialSearchStrategy(start: start, end: end)
    }
}

struct SmartSearchEngineDescriptor: SearchEngineDescriptor {
    let type: SearchEngineType = .smart
    let displayName = "Smart"
    let description = "Uses lightweight heuristics to prioritize PIDs."
    let icon = "brain"

    func makeStrategy(start: UInt16, end: UInt16) -> any SearchStrategy {
        SmartSearchStrategy(start: start, end: end)
    }
}

struct AdaptiveSearchEngineDescriptor: SearchEngineDescriptor {
    let type: SearchEngineType = .adaptive
    let displayName = "Adaptive"
    let description = "Learns during the scan and reprioritizes requests."
    let icon = "sparkles"

    func makeStrategy(start: UInt16, end: UInt16) -> any SearchStrategy {
        AdaptiveSearchStrategy(start: start, end: end)
    }
}

// MARK: - Experimental Placeholder
struct ExperimentalAdaptiveDescriptor: SearchEngineDescriptor {
    let type: SearchEngineType
    let displayName: String
    let description: String
    var icon: String {
        type.defaultIcon
    }

    func makeStrategy(start: UInt16, end: UInt16) -> any SearchStrategy {
        AdaptiveSearchStrategy(start: start, end: end)
    }
}
