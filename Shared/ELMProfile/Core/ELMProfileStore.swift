//
//  ELMProfileStore.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 17/07/2026.
//

import Foundation

actor ELMProfileStore {
    static let shared = ELMProfileStore()

    private let directoryURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = support.appendingPathComponent("ELM Profiles", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        directoryURL = directory

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    private func fileURL(for fingerprint: String) -> URL {
        let sanitized = fingerprint
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "_")

        let fileName = sanitized.isEmpty
            ? "ELMProfile_Unknown.json"
            : "ELMProfile_\(sanitized).json"
        return directoryURL.appendingPathComponent(fileName)
    }

    func load(fingerprint: String) throws -> ELMProfile? {
        let url = fileURL(for: fingerprint)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode(ELMProfile.self, from: data)
    }

    func loadAll() throws -> [ELMProfile] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "json" }

        return try urls
            .map { try Data(contentsOf: $0) }
            .map { try decoder.decode(ELMProfile.self, from: $0) }
            .sorted { $0.fingerprint.id.localizedStandardCompare($1.fingerprint.id) == .orderedAscending }
    }

    func save(_ profile: ELMProfile) throws {
        let url = fileURL(for: profile.fingerprint.id)
        let data = try encoder.encode(profile)
        try data.write(to: url, options: .atomic)
    }

    func delete(fingerprint: String) throws {
        let url = fileURL(for: fingerprint)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}
