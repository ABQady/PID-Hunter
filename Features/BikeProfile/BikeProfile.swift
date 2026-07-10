//
//  BikeProfile.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 10/07/2026.
//
import Foundation

struct BikeProfile: Codable {

    static let currentSchemaVersion = 1
    let fingerprint: BikeFingerprint
    var schemaVersion: Int = BikeProfile.currentSchemaVersion
    var displayName: String
    var firstSeen: Date = .now
    var lastSeen: Date = .now
    var discoveries: [DiscoveryKey: BikeKnowledge]

    var coverage: Double {
        guard !discoveries.isEmpty else {
            return 0
        }

        // Full 16-bit request space.
        return Double(discoveries.count) / 65536.0
    }

    var coverageString: String {
        String(format: "%.2f%%", coverage * 100)
    }

    init(
        fingerprint: BikeFingerprint,
        displayName: String? = nil,
        discoveries: [DiscoveryKey: BikeKnowledge] = [:]
    ) {
        self.fingerprint = fingerprint
        self.displayName = displayName ?? fingerprint.header
        self.discoveries = discoveries
    }
}
