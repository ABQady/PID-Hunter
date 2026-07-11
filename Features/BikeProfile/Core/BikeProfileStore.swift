//
//  BikeProfileStore.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 10/07/2026.
//

import Foundation

@MainActor
final class BikeProfileStore {

    static let shared = BikeProfileStore()

    private let fileManager = FileManager.default

    private init() {}

    private var profilesDirectory: URL {
        let base = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let directory = base.appendingPathComponent(
            "BikeProfiles",
            isDirectory: true
        )

        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }

        return directory
    }

    private func fileURL(for fingerprint: BikeFingerprint) -> URL {
        profilesDirectory.appendingPathComponent("\(fingerprint.id).json")
    }

    func exists(for fingerprint: BikeFingerprint) -> Bool {
        fileManager.fileExists(atPath: fileURL(for: fingerprint).path)
    }

    func load(for fingerprint: BikeFingerprint) throws -> BikeProfile {
        let url = fileURL(for: fingerprint)
        let data = try Data(contentsOf: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decodedProfile = try decoder.decode(BikeProfile.self, from: data)

        let profile = decodedProfile

        Logger.shared.info("📂 Loaded Bike Profile")
        return profile
    }

    func loadOrCreate(
        for fingerprint: BikeFingerprint
    ) throws -> BikeProfile {

        if exists(for: fingerprint) {
            return try load(for: fingerprint)
        }

        let profile = BikeProfile(
            fingerprint: fingerprint,
            discoveries: [:]
        )

        try save(profile)

        Logger.shared.info("🆕 Created Bike Profile")

        return profile
    }

    func loadAll() throws -> [BikeProfile] {
        _ = profilesDirectory

        let urls = try fileManager.contentsOfDirectory(
            at: profilesDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension.lowercased() == "json" }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var profiles: [BikeProfile] = []
        for url in urls {
            let data = try Data(contentsOf: url)
            let decodedProfile = try decoder.decode(BikeProfile.self, from: data)

            let profile = decodedProfile

            profiles.append(profile)
        }
        return profiles.sorted { $0.lastSeen > $1.lastSeen }
    }

    func save(_ profile: BikeProfile) throws {
        _ = profilesDirectory
        let url = fileURL(for: profile.fingerprint)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(profile)
        try data.write(to: url, options: .atomic)
        Logger.shared.info("💾 Saved Bike Profile")
    }

    func delete(_ profile: BikeProfile) throws {
        let urls = try fileManager.contentsOfDirectory(
            at: profilesDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension.lowercased() == "json" }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for url in urls {
            let data = try Data(contentsOf: url)
            let stored = try decoder.decode(BikeProfile.self, from: data)

            if stored.fingerprint == profile.fingerprint,
               stored.displayName == profile.displayName {
                try fileManager.removeItem(at: url)
                Logger.shared.info("🗑 Deleted Bike Profile")
                return
            }
        }

        throw CocoaError(.fileNoSuchFile)
    }

    func delete(for fingerprint: BikeFingerprint) throws {
        try fileManager.removeItem(at: fileURL(for: fingerprint))
    }
}
