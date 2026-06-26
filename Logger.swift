//
// Logger.swift
//
import Foundation
@MainActor
final class Logger: ObservableObject {
    static let shared = Logger()
    @Published var lines: [String] = []
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
        _ text: String
    ) {
        print(text)
        lines.append(text)
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
            "\(stamp()) >> \(command)"
        )
    }
    func rx(
        _ response: String
    ) {
        append(
            "\(stamp()) << \(response)"
        )
    }
    func info(
        _ text: String
    ) {
        append(
            "\(stamp()) [INFO] \(text)"
        )
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
        let text =
        lines.joined(
            separator: "\r\n"
        )
        try text.write(
            to: url,
            atomically: true,
            encoding: .utf8
        )
        return url
    }
}
