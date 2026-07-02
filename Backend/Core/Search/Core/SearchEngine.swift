//
//  SearchEngine.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//
import SwiftUI

struct SearchEngine: Identifiable, Hashable {

    let id = UUID()

    let descriptor: any SearchEngineDescriptor

    // MARK: - Metadata
    var type: SearchEngineType {
        descriptor.type
    }

    var displayName: String {
        descriptor.displayName
    }

    var description: String {
        descriptor.description
    }

    var icon: String {
        descriptor.icon
    }

    var supportsBenchmark: Bool {
        descriptor.supportsBenchmark
    }

    // MARK: - Factory
    func makeStrategy(
        start: UInt16,
        end: UInt16
    ) -> any SearchStrategy {
        descriptor.makeStrategy(
            start: start,
            end: end
        )
    }

    static func == (lhs: SearchEngine, rhs: SearchEngine) -> Bool {
        lhs.type == rhs.type
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(type)
    }
}
