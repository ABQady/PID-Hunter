//
// Logger.swift
//
import Foundation

private enum LogLevel {
    case user
    case debug
}


enum DebugVerbosity: Int {
    case normal = 1
    case verbose = 2
}

enum VerboseCategory: String, CaseIterable {
    case communication
    case assembler
    case parser
    case transport
    case scanner
    case discovery
    case persistence
    case setup
    case telemetry
    case outcome
    case lifecycle
    case bluetooth
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

struct LogLine: Identifiable, Equatable {
    let id: Int64
    let text: String
    let style: LogStyle
}

actor Logger {
    static let shared = Logger()
    private var nextID: Int64 = 0

    private var lines: [LogLine] = []
    private let sink = BufferedFileSink()
    private static let trimChunk = 256
    private let maxLines = 5000

    private let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
    
    private var enableDebugLogging: Bool {
        UserDefaults.standard.bool(forKey: "enableDebugLogging")
    }

    private var debugVerbosity: DebugVerbosity {
        DebugVerbosity(
            rawValue: UserDefaults.standard.integer(forKey: "debugVerbosity")
        ) ?? .normal
    }

    private func isVerboseCategoryEnabled(_ category: VerboseCategory) -> Bool {
        UserDefaults.standard.bool(forKey: "verboseCategory.\(category.rawValue)")
    }
    
    private init() {
        lines.reserveCapacity(maxLines)
    }

    private var continuations: [AsyncStream<[LogLine]>.Continuation] = []

    private func registerContinuation(
        _ continuation: AsyncStream<[LogLine]>.Continuation
    ) {
        continuations.append(continuation)
        continuation.yield(lines)
    }

    nonisolated func stream() -> AsyncStream<[LogLine]> {
        AsyncStream { continuation in
            Task {
                await self.registerContinuation(continuation)
            }

            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task {
                    await self.removeContinuation(continuation)
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
        level: LogLevel = .user,
        verboseOnly: Bool = false
    ) {
        guard level == .user || enableDebugLogging else {
            return
        }
        if verboseOnly,
           debugVerbosity != .verbose {
            return
        }
        if text.isEmpty { return }
        let timestamp = timestampFormatter.string(from: .now)
        print(text)
        let line = makeLogLine(
            text: "\(timestamp) \(text)",
            style: style
        )
        // Journal persistence is independent from the in-memory terminal.
        // Terminal rendering must continue to work even if log persistence changes.
        sink.write(line.text)
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

    func verboseImpl(_ text: String) {
        append(
            "[DEBUG] \(text)",
            style: .debug,
            level: .debug,
            verboseOnly: true
        )
    }

    func verboseImpl(_ category: VerboseCategory, _ text: String) {
        guard isVerboseCategoryEnabled(category) else {
            return
        }
        append(
            "[DEBUG][\(category.rawValue.uppercased())] \(text)",
            style: .debug,
            level: .debug,
            verboseOnly: true
        )
    }

    @inline(__always)
    nonisolated func console(_ text: String) {
        Task {
            await self.infoImpl(text)
        }
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
    func exportCurrentLog() throws -> URL {
        if let sourceURL = sink.currentFileURL {
            // Active journal file exists; flush and export it.
            sink.flush()
            // Create a unique export file in the temp directory
            let exportURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    sourceURL.deletingPathExtension().lastPathComponent
                    + "-Export-\(UUID().uuidString).log"
                )
            if FileManager.default.fileExists(atPath: exportURL.path) {
                try FileManager.default.removeItem(at: exportURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: exportURL)
            return exportURL
        } else {
            // No journal file; export the in-memory terminal contents.
            let exportURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("Terminal-\(UUID().uuidString).log")
            let contents = lines.map(\.text).joined(separator: "\n")
            try contents.write(to: exportURL, atomically: true, encoding: .utf8)
            return exportURL
        }
    }
    
     func startSessionImpl(fileURL: URL) throws {
        try sink.startSession(fileURL: fileURL)
    }

     func finishSessionImpl() {
        sink.finish()
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


    nonisolated func verbose(_ text: String) {
        Task {
            await self.verboseImpl(text)
        }
    }

    nonisolated func verbose(_ category: VerboseCategory, _ text: String) {
        Task {
            await self.verboseImpl(category, text)
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
