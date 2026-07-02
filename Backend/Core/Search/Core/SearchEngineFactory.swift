//
//  SearchEngineFactory.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//

import Foundation

enum SearchEngineFactory {

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

    // MARK: - Public API

    static func engine(
        for type: SearchEngineType
    ) -> SearchEngine? {
        guard let descriptor = descriptor(for: type) else {
            return nil
        }

        return SearchEngine(descriptor: descriptor)
    }

    static func make(
        type: SearchEngineType,
        start: UInt16,
        end: UInt16
    ) -> any SearchStrategy {
        guard let descriptor = descriptor(for: type) else {
            preconditionFailure("No SearchEngine registered for \(type)")
        }

        return descriptor.makeStrategy(
            start: start,
            end: end
        )
    }
}
