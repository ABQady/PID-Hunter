//
//  Exporter.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 11/07/2026.
//

import Foundation

enum Exporter {

    private static var exportDirectory: URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Exports", isDirectory: true)

        try? FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )

        return url
    }

    static func write(
        _ text: String,
        filename: String
    ) throws -> URL {
        try write(
            Data(text.utf8),
            filename: filename
        )
    }

    static func write(
        _ data: Data,
        filename: String
    ) throws -> URL {
        let url = exportDirectory.appendingPathComponent(filename)

        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }

        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Bike Profile
    static func export(_ profile: BikeProfile) throws -> URL {

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(profile)

        let filename = sanitizedFilename(profile.displayName) + ".json"
        let url = try write(
            data,
            filename: filename
        )

        Logger.shared.success("📤 Bike Profile exported")
        Logger.shared.info(url.lastPathComponent)

        return url
    }

    // MARK: - Scan Results
    static func export(_ results: [ScanResult]) throws -> URL {
        var csv = "Header,Mode,PID,Request,Response\n"

        for result in results {
            csv += "\(csvField(result.header)),"
            csv += "\(csvField(result.mode)),"
            csv += "\(csvField(result.pid)),"
            csv += "\(csvField(result.request)),"
            csv += "\(csvField(result.response))\n"
        }

        return try write(
            csv,
            filename: "ScanResults.csv"
        )
    }

    // MARK: - CSV Helpers
    private static func escapeCSV(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }

    private static func csvField(_ field: String) -> String {
        return escapeCSV(field)
    }

    // MARK: - Helpers
    private static func sanitizedFilename(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "\\/:*?\"<>|")

        let cleaned = name
            .components(separatedBy: invalid)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? "BikeProfile" : cleaned
    }
}
