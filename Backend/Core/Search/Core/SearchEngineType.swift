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

    // MARK: - Categories

    var isCore: Bool {
        switch self {
        case .sequential, .smart, .adaptive:
            return true
        default:
            return false
        }
    }

    var isExperimental: Bool {
        !isCore
    }
}
