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

    // MARK: - Defaults

    static var `default`: SearchEngine? {
        engine(.adaptive)
    }

    static var core: [SearchEngine] {
        all.filter(\.type.isCore)
    }

    static var experimental: [SearchEngine] {
        all.filter(\.type.isExperimental)
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
        return SearchEngineFactory.engine(for: type)
    }
}
