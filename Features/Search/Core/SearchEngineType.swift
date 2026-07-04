//
//  SearchEngineType.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//

import Foundation

enum SearchEngineType: String, CaseIterable, Codable, Identifiable {
    var id: Self { self }
    
    case sequential
    case smart
    case adaptive
    case ucb
    case thompson
    case heatMap
    case cluster
    case hybrid

    // MARK: - Identity

    var displayName: String {
        switch self {
        case .sequential: return "Sequential"
        case .smart: return "Smart"
        case .adaptive: return "Adaptive"
        case .ucb: return "UCB"
        case .thompson: return "Thompson"
        case .heatMap: return "Heat Map"
        case .cluster: return "Cluster"
        case .hybrid: return "Hybrid"
        }
    }

    // MARK: - Categories

    private static let coreEngines: Set<SearchEngineType> = [
        .sequential,
        .smart,
        .adaptive
    ]

    var isCore: Bool {
        Self.coreEngines.contains(self)
    }

    @inline(__always)
    var isExperimental: Bool {
        !isCore
    }
}
