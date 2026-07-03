//
//  SearchEngineRegistry.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//

import Foundation

enum SearchEngineRegistry {

    private static var descriptors: [SearchEngineType: any SearchEngineDescriptor] = [:]

    @inline(__always)
    private static func descriptorKey(
        for descriptor: any SearchEngineDescriptor
    ) -> SearchEngineType {
        descriptor.type
    }

    // MARK: - Registration

    static func register(_ descriptor: any SearchEngineDescriptor) {
        let type = descriptorKey(for: descriptor)

        precondition(
            descriptors[type] == nil,
            "Duplicate SearchEngine registration: \(type)"
        )

        descriptors[type] = descriptor
    }

    // MARK: - Lookup

    static func descriptor(for type: SearchEngineType) -> (any SearchEngineDescriptor)? {
        descriptors[type]
    }

    @inline(__always)
    private static func descriptorForAllCases(
        _ type: SearchEngineType
    ) -> (any SearchEngineDescriptor)? {
        descriptors[type]
    }

    @inline(__always)
    static var allDescriptors: [any SearchEngineDescriptor] {
        SearchEngineType.allCases.compactMap(descriptorForAllCases)
    }

    // MARK: - Maintenance

    static func removeAll() {
        descriptors.removeAll(keepingCapacity: true)
    }
}
