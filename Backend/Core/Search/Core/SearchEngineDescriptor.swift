//
//  SearchEngineDescriptor.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//
protocol SearchEngineDescriptor {
    var type: SearchEngineType { get }
    var displayName: String { get }
    var description: String { get }
    var icon: String { get }
    var supportsBenchmark: Bool { get }
    func makeStrategy(
        start: UInt16,
        end: UInt16
    ) -> any SearchStrategy
}

struct SequentialSearchEngineDescriptor: SearchEngineDescriptor {
    let type: SearchEngineType = .sequential
    let displayName = "Sequential"
    let description = "Scans PIDs sequentially."
    let icon = "list.number"
    let supportsBenchmark = true

    func makeStrategy(start: UInt16, end: UInt16) -> any SearchStrategy {
        SequentialSearchStrategy(start: start, end: end)
    }
}

struct SmartSearchEngineDescriptor: SearchEngineDescriptor {
    let type: SearchEngineType = .smart
    let displayName = "Smart"
    let description = "Uses lightweight heuristics to prioritize PIDs."
    let icon = "brain"
    let supportsBenchmark = true

    func makeStrategy(start: UInt16, end: UInt16) -> any SearchStrategy {
        SmartSearchStrategy(start: start, end: end)
    }
}

struct AdaptiveSearchEngineDescriptor: SearchEngineDescriptor {
    let type: SearchEngineType = .adaptive
    let displayName = "Adaptive"
    let description = "Learns during the scan and reprioritizes requests."
    let icon = "sparkles"
    let supportsBenchmark = true

    func makeStrategy(start: UInt16, end: UInt16) -> any SearchStrategy {
        AdaptiveSearchStrategy(start: start, end: end)
    }
}

struct ExperimentalAdaptiveDescriptor: SearchEngineDescriptor {
    let type: SearchEngineType
    let displayName: String
    let description: String
    let icon: String
    let supportsBenchmark = true

    func makeStrategy(start: UInt16, end: UInt16) -> any SearchStrategy {
        AdaptiveSearchStrategy(start: start, end: end)
    }
}
