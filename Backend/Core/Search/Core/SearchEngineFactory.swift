//
//  SearchEngineFactory.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//

import Foundation

enum SearchEngineFactory {

    private typealias Registry = [SearchEngineType: any SearchEngineDescriptor]

    // MARK: - Registry

    private static var registry: Registry = [:]

    // MARK: - Registration

    static func register(_ descriptor: any SearchEngineDescriptor) {
        registry[descriptor.type] = descriptor
    }

    // MARK: - Public API

    static func engine(
        for type: SearchEngineType
    ) -> SearchEngine? {
        SearchEngineBootstrap.registerAll()

        guard let descriptor = registry[type] else {
            return nil
        }

        return SearchEngine(descriptor: descriptor)
    }

    static func make(
        type: SearchEngineType,
        start: UInt16,
        end: UInt16
    ) -> any SearchStrategy {
        SearchEngineBootstrap.registerAll()

        guard let descriptor = registry[type] else {
            preconditionFailure("No SearchEngine registered for \(type)")
        }

        return descriptor.makeStrategy(
            start: start,
            end: end
        )
    }
}
