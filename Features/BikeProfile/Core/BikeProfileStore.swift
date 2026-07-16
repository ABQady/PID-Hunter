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

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

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

    private func fileURLs(for fingerprint: BikeFingerprint) -> [URL] {
        (try? fileManager.contentsOfDirectory(
            at: profilesDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ))?
        .filter {
            $0.pathExtension.lowercased() == "json" &&
            $0.deletingPathExtension().lastPathComponent.hasPrefix("\(fingerprint.id)_")
        } ?? []
    }

    private func fileURL(for profile: BikeProfile) -> URL {
        let shortID = String(profile.id.uuidString.prefix(8))
        let filename = "\(profile.fingerprint.id)_\(shortID).json"
        return profilesDirectory.appendingPathComponent(filename)
    }

    private func loadProfile(from url: URL) throws -> BikeProfile {
        let data = try Data(contentsOf: url)
        return try decoder.decode(BikeProfile.self, from: data)
    }

    func exists(for fingerprint: BikeFingerprint) -> Bool {
        !fileURLs(for: fingerprint).isEmpty
    }

    func load(for fingerprint: BikeFingerprint) throws -> BikeProfile {
        let urls = fileURLs(for: fingerprint)
        guard let url = urls.first else {
            throw CocoaError(.fileNoSuchFile)
        }

        let profile: BikeProfile
        do {
            profile = try loadProfile(from: url)
        } catch {
            Logger.shared.error("❌ Failed to decode Bike Profile: \(url.lastPathComponent)")
            throw error
        }

        Logger.shared.info("📂 Loaded Bike Profile")
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

        var profiles: [BikeProfile] = []
        for url in urls {
            do {
                let profile = try loadProfile(from: url)
                profiles.append(profile)
            } catch {
                Logger.shared.warning("⚠️ Skipping invalid Bike Profile: \(url.lastPathComponent)")
                continue
            }
        }
        return profiles.sorted { $0.lastSeen > $1.lastSeen }
    }

    func save(_ profile: BikeProfile) throws {
        _ = profilesDirectory
        let url = fileURL(for: profile)

        let data = try self.encoder.encode(profile)
        try data.write(to: url, options: .atomic)
        Logger.shared.info("💾 Saved Bike Profile")
        Logger.shared.verbose(.persistence, """
        💾 SAVE
        UUID        : \(profile.id)
        Discoveries : \(profile.discoveries.count)
        Object      : \(ObjectIdentifier(profile as AnyObject))
        File        : \(url.lastPathComponent)
        """)
    }

    func delete(_ profile: BikeProfile) throws {
        let urls = try fileManager.contentsOfDirectory(
            at: profilesDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension.lowercased() == "json" }

        for url in urls {
            let stored = try loadProfile(from: url)

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
        for url in fileURLs(for: fingerprint) {
            try fileManager.removeItem(at: url)
        }
    }
}
