//
//  SearchEngineRegistry.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//

import Foundation

enum SearchEngineRegistry {

    private static var descriptors: [SearchEngineType: any SearchEngineDescriptor] = [:]

    static func register(_ descriptor: any SearchEngineDescriptor) {
        let type = descriptor.type

        precondition(
            descriptors[type] == nil,
            "Duplicate SearchEngine registration: \(type)"
        )

        descriptors[type] = descriptor
    }

    static func descriptor(for type: SearchEngineType) -> (any SearchEngineDescriptor)? {
        descriptors[type]
    }

    static var allDescriptors: [any SearchEngineDescriptor] {
        SearchEngineType.allCases.compactMap { descriptors[$0] }
    }

    static func removeAll() {
        descriptors.removeAll()
    }
}
