//
// Logger.swift
//
import Foundation

private enum LogLevel {
    case user
    case debug
}

enum LogStyle {
    case tx
    case rx
    case info
    case success
    case warning
    case error
    case debug
}

struct LogLine: Identifiable {
    let id: Int64
    let text: String
    let style: LogStyle
}

actor Logger {
    static let shared = Logger()
    private var nextID: Int64 = 0

    private var lines: [LogLine] = []
    private static let trimChunk = 256
    private let maxLines = 5000
    private static let logFilename = "rawTraffic.log"

    private let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
    
    private var enableDebugLogging: Bool {
        UserDefaults.standard.bool(forKey: "enableDebugLogging")
    }
    
    private init() {
        lines.reserveCapacity(maxLines)
    }

    private var continuations: [AsyncStream<[LogLine]>.Continuation] = []

    func stream() -> AsyncStream<[LogLine]> {
        AsyncStream { continuation in
            continuations.append(continuation)
            continuation.yield(lines)
            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.removeContinuation(continuation)
                }
            }
        }
    }

    private func removeContinuation(
        _ continuation: AsyncStream<[LogLine]>.Continuation
    ) {
        continuations.removeAll {
            ObjectIdentifier($0 as AnyObject) ==
            ObjectIdentifier(continuation as AnyObject)
        }
    }

    @inline(__always)
    private func currentSnapshot() -> [LogLine] {
        lines
    }

    private func publish() {
        guard !continuations.isEmpty else {
            return
        }
        let snapshotLines = currentSnapshot()
        let snapshot = continuations
        for continuation in snapshot {
            continuation.yield(snapshotLines)
        }
    }
    // MARK: - Logging

    @inline(__always)
    private func makeLogLine(text: String, style: LogStyle) -> LogLine {
        defer { nextID &+= 1 }
        return LogLine(
            id: nextID,
            text: text,
            style: style
        )
    }

    @inline(__always)
    private func append(
        _ text: String,
        style: LogStyle,
        level: LogLevel = .user
    ) {
        guard level == .user || enableDebugLogging else {
            return
        }
        if text.isEmpty { return }
        let timestamp = timestampFormatter.string(from: .now)
        console(text)
        let line = makeLogLine(
            text: "\(timestamp) \(text)",
            style: style
        )

        lines.append(line)
        let overflow = lines.count - maxLines
        if overflow > 0 {
            lines.removeFirst(min(Self.trimChunk, overflow))
        }
        publish()
    }

    // MARK: - Public API

    func txImpl(
        _ command: String
    ) {
        append(
            ">> \(command)", style: .tx, level: .debug)
    }
    func rxImpl(
        _ response: String
    ) {
        append(
            "<< \(response)", style: .rx, level: .debug)
    }
    func infoImpl(
        _ text: String
    ) {
        append("[INFO] \(text)", style: .info, level: .user)
    }
    func successImpl(_ text: String) {
        append("✅ \(text)", style: .success, level: .user)
    }

    func warningImpl(_ text: String) {
        append("⚠️ \(text)", style: .warning, level: .user)
    }

    func errorImpl(_ text: String) {
        append("❌ \(text)", style: .error, level: .user)
    }

    func debugImpl(_ text: String) {
        append("[DEBUG] \(text)",
               style: .debug,
               level: .debug)
    }

    @inline(__always)
    nonisolated func console(_ text: String) {
        print(text)
    }

    // MARK: - Maintenance

    func snapshot() -> [LogLine] {
        Array(lines)
    }

    func clearImpl() {
        guard !lines.isEmpty else { return }
        lines.removeAll(keepingCapacity: true)
        publish()
    }
    func saveLog() throws -> URL {
        let filename = Self.logFilename
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        var output = String()
        output.reserveCapacity(lines.count * 48)
        for line in lines {
            output.append(line.text)
            output.append("\n")
        }
        try output.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    nonisolated func error(_ text: String) {
        Task {
            await self.errorImpl(text)
        }
    }

    nonisolated func info(_ text: String) {
        Task {
            await self.infoImpl(text)
        }
    }

    nonisolated func debug(_ text: String) {
        Task {
            await self.debugImpl(text)
        }
    }

    nonisolated func warning(_ text: String) {
        Task {
            await self.warningImpl(text)
        }
    }

    nonisolated func success(_ text: String) {
        Task {
            await self.successImpl(text)
        }
    }

    nonisolated func tx(_ text: String) {
        Task {
            await self.txImpl(text)
        }
    }

    nonisolated func rx(_ text: String) {
        Task {
            await self.rxImpl(text)
        }
    }

    nonisolated func clear() {
        Task {
            await self.clearImpl()
        }
    }
}
