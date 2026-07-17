//
//  BikeProfile.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 10/07/2026.
//
import Foundation

struct BikeProfile: Codable, Hashable {
    let id: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case fingerprint
        case schemaVersion
        case displayName
        case firstSeen
        case lastSeen
        case discoveries
        case deviceDiscoveries
        case legacyHeaderDiscoveries = "headerDiscoveries"
    }

    static let currentSchemaVersion = 1
    var fingerprint: BikeFingerprint
    var schemaVersion: Int = BikeProfile.currentSchemaVersion
    var displayName: String
    var firstSeen: Date = .now
    var lastSeen: Date = .now
    var discoveries: [DiscoveryRecord]
    var deviceDiscoveries: [DeviceDiscoveryRecord] = []
    private var legacyHeaderDiscoveries: [HeaderDiscoveryResult] = []

    var headerDiscoveries: [HeaderDiscoveryResult] {
        if !deviceDiscoveries.isEmpty {
            return Dictionary(
                grouping: deviceDiscoveries,
                by: { String(format: "%02X", $0.respondingAddress) }
            )
            .keys
            .sorted()
            .map {
                HeaderDiscoveryResult(
                    header: $0,
                    supportedModes: []
                )
            }
        }

        return legacyHeaderDiscoveries
    }

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
        deviceDiscoveries: [DeviceDiscoveryRecord] = [],
        headerDiscoveries: [HeaderDiscoveryResult] = []
    ) {
        self.id = UUID()
        self.fingerprint = fingerprint
        self.displayName = displayName ?? "Unknown Name"
        self.discoveries = discoveries
        self.deviceDiscoveries = deviceDiscoveries
        self.legacyHeaderDiscoveries = headerDiscoveries
        self.lastSeen = self.firstSeen
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        fingerprint = try container.decode(BikeFingerprint.self, forKey: .fingerprint)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? "Unknown Name"
        firstSeen = try container.decodeIfPresent(Date.self, forKey: .firstSeen) ?? .now
        lastSeen = try container.decodeIfPresent(Date.self, forKey: .lastSeen) ?? firstSeen
        discoveries = try container.decodeIfPresent([DiscoveryRecord].self, forKey: .discoveries) ?? []
        deviceDiscoveries = try container.decodeIfPresent([DeviceDiscoveryRecord].self, forKey: .deviceDiscoveries) ?? []
        legacyHeaderDiscoveries = try container.decodeIfPresent([HeaderDiscoveryResult].self, forKey: .legacyHeaderDiscoveries) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(fingerprint, forKey: .fingerprint)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(firstSeen, forKey: .firstSeen)
        try container.encode(lastSeen, forKey: .lastSeen)
        try container.encode(discoveries, forKey: .discoveries)
        try container.encode(deviceDiscoveries, forKey: .deviceDiscoveries)
        if deviceDiscoveries.isEmpty {
            try container.encode(legacyHeaderDiscoveries, forKey: .legacyHeaderDiscoveries)
        }
    }
}
// MARK: - Discovery Queries
extension BikeProfile {

    @inline(__always)
    private func sortedDiscoveries(
        matching predicate: (DiscoveryRecord) -> Bool
    ) -> [DiscoveryRecord] {
        discoveries
            .filter(predicate)
            .sorted { $0.request < $1.request }
    }

    @inline(__always)
    private func discoveries(
        where predicate: (DiscoveryRecord) -> Bool
    ) -> [DiscoveryRecord] {
        sortedDiscoveries(matching: predicate)
    }

    func discoveries(
        classifiedAs classification: DiscoveryClassification
    ) -> [DiscoveryRecord] {
        discoveries { $0.classification == classification }
    }

    func positiveDiscoveries() -> [DiscoveryRecord] {
        discoveries(classifiedAs: .positive)
    }

    func negativeDiscoveries() -> [DiscoveryRecord] {
        discoveries(classifiedAs: .negative)
    }

    func partialFrameDiscoveries() -> [DiscoveryRecord] {
        discoveries(classifiedAs: .partialFrame)
    }

    func noDataDiscoveries() -> [DiscoveryRecord] {
        discoveries(classifiedAs: .noData)
    }

    func unknownDiscoveries() -> [DiscoveryRecord] {
        discoveries(classifiedAs: .unknown)
    }
}
