//
//  BikeProfile.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 10/07/2026.
//
import Foundation

struct BikeProfile: Codable, Hashable {
    let id: UUID

    static let currentSchemaVersion = 1
    var fingerprint: BikeFingerprint
    var schemaVersion: Int = BikeProfile.currentSchemaVersion
    var displayName: String
    var firstSeen: Date = .now
    var lastSeen: Date = .now
    var discoveries: [DiscoveryRecord]
    var headerDiscoveries: [HeaderDiscoveryResult] = []

    mutating func touch() {
        lastSeen = .now
    }

    mutating func rename(to name: String) {
        displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        touch()
    }

    init(
        fingerprint: BikeFingerprint,
        displayName: String? = nil,
        discoveries: [DiscoveryRecord] = [],
        headerDiscoveries: [HeaderDiscoveryResult] = []
    ) {
        self.id = UUID()
        self.fingerprint = fingerprint
        self.displayName = displayName ?? fingerprint.header
        self.discoveries = discoveries
        self.headerDiscoveries = headerDiscoveries
        self.lastSeen = self.firstSeen
    }
}
extension BikeProfile {

    func discoveries(
        classifiedAs classification: DiscoveryClassification
    ) -> [DiscoveryRecord] {

        discoveries
            .filter {
                $0.classification == classification
            }
            .sorted {
                $0.request < $1.request
            }
    }
}
