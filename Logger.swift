//
// Logger.swift
//
import Foundation
import SwiftUI

enum LogLevel {
    case user
    case debug
}

struct LogLine: Identifiable {
    let id = UUID()
    let text: String
    let color: Color
}

@MainActor
final class Logger: ObservableObject {
    static let shared = Logger()

    @Published var lines: [LogLine] = []
    @AppStorage("enableDebugLogging")
    private var enableDebugLogging = false
    private let maxLines = 5000
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
    private init() {}
    private func stamp() -> String {
        formatter.string(
            from: Date()
        )
    }
    private func append(
        _ text: String,
        color: Color,
        level: LogLevel = .user
    ) {
        guard level == .user || enableDebugLogging else {
            return
        }
        console(text)
        lines.append(LogLine(
            text: text,
            color: color
        ))
        if lines.count > maxLines {
            lines.removeFirst(
                lines.count - maxLines
            )
        }
    }
    func tx(
        _ command: String
    ) {
        append(
            "\(stamp()) >> \(command)", color: .blue, level: .debug)
    }
    func rx(
        _ response: String
    ) {
        append(
            "\(stamp()) << \(response)",color: .green, level: .debug)
    }
    func info(
        _ text: String
    ) {
        append(
            "\(stamp()) [INFO] \(text)",color: .primary, level: .user)
    }
    func success(_ text: String) {
        append("\(stamp()) ✅ \(text)", color: .mint, level: .user)
    }

    func warning(_ text: String) {
        append("\(stamp()) ⚠️ \(text)", color: .orange, level: .user)
    }

    func error(_ text: String) {
        append("\(stamp()) ❌ \(text)", color: .red, level: .user)
    }

    func debug(_ text: String) {
        append("\(stamp()) [DEBUG] \(text)",
               color: .secondary,
               level: .debug)
    }

    func console(_ text: String) {
        guard enableDebugLogging else { return }
        print(text)
    }

    func clear() {
        lines.removeAll()
    }
    func saveLog() throws -> URL {
        let url =
        FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "rawTraffic.log"
            )
        let text = lines
            .map(\.text)
            .joined(separator: "\r\n")
        try text.write(
            to: url,
            atomically: true,
            encoding: .utf8
        )
        return url
    }
}
