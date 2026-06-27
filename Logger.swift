//
// Logger.swift
//
import Foundation
import SwiftUI

struct LogLine: Identifiable {
    let id = UUID()
    let text: String
    let color: Color
}

@MainActor
final class Logger: ObservableObject {
    static let shared = Logger()

    @Published var lines: [LogLine] = []
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
        color: Color
    ) {
        print(text)
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
            "\(stamp()) >> \(command)", color: .blue)
    }
    func rx(
        _ response: String
    ) {
        append(
            "\(stamp()) << \(response)",color: .green)
    }
    func info(
        _ text: String
    ) {
        append(
            "\(stamp()) [INFO] \(text)",color: .primary)
    }
    func success(_ text: String) {
        append("\(stamp()) ✅ \(text)", color: .mint)
    }

    func warning(_ text: String) {
        append("\(stamp()) ⚠️ \(text)", color: .orange)
    }

    func error(_ text: String) {
        append("\(stamp()) ❌ \(text)", color: .red)
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
