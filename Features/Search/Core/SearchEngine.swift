//
//  SearchEngine.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//
import Foundation

struct SearchEngine: Identifiable, Hashable {

    let descriptor: any SearchEngineDescriptor

    @inline(__always)
    private var metadata: any SearchEngineDescriptor {
        descriptor
    }

    // MARK: - Identifiable
    var id: SearchEngineType {
        type
    }

    // MARK: - Metadata
    @inline(__always)
    var type: SearchEngineType {
        metadata.type
    }

    var displayName: String {
        metadata.displayName
    }

    var description: String {
        metadata.description
    }

    var icon: String {
        metadata.icon
    }

    var supportsBenchmark: Bool {
        metadata.supportsBenchmark
    }

    // MARK: - Classification
    var isCore: Bool {
        type.isCore
    }

    var isExperimental: Bool {
        type.isExperimental
    }

    // MARK: - Factory
    func makeStrategy(
        start: UInt16,
        end: UInt16
    ) -> any SearchStrategy {
        metadata.makeStrategy(
            start: start,
            end: end
        )
    }

    // MARK: - Equatable & Hashable
    @inline(__always)
    static func == (lhs: SearchEngine, rhs: SearchEngine) -> Bool {
        lhs.id == rhs.id
    }

    @inline(__always)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
