//
//  SearchEngineCatalog.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//

import Foundation

@MainActor
enum SearchEngineCatalog {

    // MARK: - Collections

    static var all: [SearchEngine] {
        SearchEngineBootstrap.registerAll()

        return SearchEngineType.allCases.compactMap {
            SearchEngineFactory.engine(for: $0)
        }
    }

    static var `default`: SearchEngine? {
        engine(.adaptive)
    }

    static var core: [SearchEngine] {
        all.filter {
            switch $0.type {
            case .sequential, .smart, .adaptive:
                return true
            default:
                return false
            }
        }
    }

    static var experimental: [SearchEngine] {
        all.filter { !core.contains($0) }
    }

    static var benchmarkable: [SearchEngine] {
        all.filter(\.supportsBenchmark)
    }

    // MARK: - Utilities

    static func contains(
        _ type: SearchEngineType
    ) -> Bool {
        engine(type) != nil
    }

    // MARK: - Lookup

    static func engine(
        _ type: SearchEngineType
    ) -> SearchEngine? {
        SearchEngineBootstrap.registerAll()
        return SearchEngineFactory.engine(for: type)
    }

    static func refresh() {
        SearchEngineBootstrap.registerAll()
    }
}
