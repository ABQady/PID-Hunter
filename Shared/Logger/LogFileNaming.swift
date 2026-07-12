//
//  LogFileNaming.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 12/07/2026.
//

import Foundation

struct LogFileNaming {

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()

    static func makeFilename(
        mode: OBDMode,
        header: String,
        searchEngine: SearchEngineType,
        startedAt: Date = .now
    ) -> String {
        let timestamp = Self.formatter.string(from: startedAt)
        return "\(timestamp)_Mode\(mode.rawValue)_Header\(header)_\(searchEngine.rawValue).log"
    }
}
