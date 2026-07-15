//
//  LogSessionManager.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 12/07/2026.
//

import Foundation

final class LogSessionManager {

    static let shared = LogSessionManager()

    private let fileManager = FileManager.default

    private(set) var sessionFolderURL: URL?
    private(set) var nextPreScanLogURL: URL?

    private(set) var isLoggingSessionActive = false
    private var currentMetadata: Metadata?
    private var sessionStartDate: Date?

    
    private init() {}

    // MARK: - Settings
    private enum Settings {
        private static let defaults = UserDefaults.standard

        static var requestTimeout: TimeInterval {
            guard defaults.object(forKey: "requestTimeout") != nil else {
                return 2.0
            }
            return defaults.double(forKey: "requestTimeout")
        }

        static var autoPreflight: Bool {
            guard defaults.object(forKey: "enableAutoPreflight") != nil else {
                return true
            }
            return defaults.bool(forKey: "enableAutoPreflight")
        }

        static var debugLogging: Bool {
            guard defaults.object(forKey: "enableDebugLogging") != nil else {
                return false
            }
            return defaults.bool(forKey: "enableDebugLogging")
        }
    }

    // MARK: - Log File Helpers
    private func createNextPreScanLogLocked() throws {

        guard let sessionFolderURL else {
            return
        }

        let timestamp = Self.sessionFormatter.string(from: .now)
        let filename = "\(timestamp)_PreScan.log"

        let url = sessionFolderURL
            .appendingPathComponent(filename)

        if !fileManager.fileExists(atPath: url.path) {
            fileManager.createFile(
                atPath: url.path,
                contents: nil
            )
        }

        nextPreScanLogURL = url
    }

    // MARK: - PreScan Session Lifecycle
    func startInitialPreScanSessionIfNeeded(
        logger: Logger
    ) async throws {

        print("🚀 beginLoggingSessionIfNeeded entered")
        Logger.shared.verbose("beginLoggingSessionIfNeeded entered")
        
        guard !isLoggingSessionActive else {
            return
        }

        let documents = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!

        let logsFolder = documents
            .appendingPathComponent("Logs", isDirectory: true)

        try fileManager.createDirectory(
            at: logsFolder,
            withIntermediateDirectories: true
        )
        print("📁 Logs folder:", logsFolder.path)
        
        let folderName = Self.sessionFormatter.string(from: .now)

        let sessionFolder = logsFolder
            .appendingPathComponent(folderName, isDirectory: true)

        try fileManager.createDirectory(
            at: sessionFolder,
            withIntermediateDirectories: true
        )
        print("📂 Session folder:", sessionFolder.path)

        sessionFolderURL = sessionFolder
        print("✅ sessionFolderURL assigned")
        sessionStartDate = .now
        isLoggingSessionActive = true

        try createNextPreScanLogLocked()

        guard let preScanLogURL = nextPreScanLogURL else {
            throw CocoaError(.fileNoSuchFile)
        }

        currentMetadata = Metadata(
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            mode: nil,
            header: nil,
            searchEngine: nil,
            requestDelay: nil,
            requestTimeout: Settings.requestTimeout,
            autoPreflight: Settings.autoPreflight,
            debugLogging: Settings.debugLogging
        )
        try await logger.startSessionImpl(fileURL: preScanLogURL)
        if let metadata = currentMetadata {
            await writeMetadataHeader(metadata, logger: logger)
        }
    }

    func createNextPreScanLog() throws {
        try createNextPreScanLogLocked()
    }


    var pendingPreScanLogURL: URL? {
        nextPreScanLogURL
    }

    struct Metadata {
        let appVersion: String
        let mode: OBDMode?
        let header: String?
        let searchEngine: SearchEngineType?
        let requestDelay: TimeInterval?
        let requestTimeout: TimeInterval?
        let autoPreflight: Bool?
        let debugLogging: Bool?
    }

    private func updatedMetadata(
        mode: OBDMode? = nil,
        header: String? = nil,
        searchEngine: SearchEngineType? = nil,
        requestDelay: TimeInterval? = nil
    ) -> Metadata? {
        guard let current = currentMetadata else {
            return nil
        }

        return Metadata(
            appVersion: current.appVersion,
            mode: mode,
            header: header,
            searchEngine: searchEngine,
            requestDelay: requestDelay ?? current.requestDelay,
            requestTimeout: current.requestTimeout,
            autoPreflight: current.autoPreflight,
            debugLogging: current.debugLogging
        )
    }

    struct Summary {
        let elapsedTime: TimeInterval
        let requests: Int
        let responses: Int
        let positives: Int
        let negatives: Int
        let partials: Int
        let timeouts: Int
    }


    private func createScanLogURL(
        mode: OBDMode,
        header: String,
        searchEngine: SearchEngineType
    ) throws -> URL {
        guard let sessionFolderURL else {
            throw CocoaError(.fileNoSuchFile)
        }

        let filename = LogFileNaming.makeFilename(
            mode: mode,
            header: header,
            searchEngine: searchEngine
        )

        let url = sessionFolderURL.appendingPathComponent(filename)

        if !fileManager.fileExists(atPath: url.path) {
            fileManager.createFile(atPath: url.path, contents: nil)
        }

        return url
    }

    // MARK: - Scan Session Lifecycle
    func startScanSession(
        mode: OBDMode,
        header: String,
        searchEngine: SearchEngineType,
        requestDelay: TimeInterval,
        logger: Logger
    ) async throws {

        currentMetadata = updatedMetadata(
            mode: mode,
            header: header,
            searchEngine: searchEngine,
            requestDelay: requestDelay
        )


        let stats = await MainActor.run { ScanStatistics.shared }

        await writeSummary(
            .init(
                elapsedTime: stats.elapsed(at: .now),
                requests: stats.requestsSent,
                responses: stats.responses,
                positives: stats.positiveResponses,
                negatives: stats.negativeResponses,
                partials: stats.partialFrames,
                timeouts: stats.timeouts
            ),
            logger: logger
        )

        try await closeCurrentLog(logger: logger)

        let scanLogURL = try createScanLogURL(
            mode: mode,
            header: header,
            searchEngine: searchEngine
        )
        try await logger.startSessionImpl(fileURL: scanLogURL)
        isLoggingSessionActive = true

        if let metadata = currentMetadata {
            await writeMetadataHeader(metadata, logger: logger)
        }
        // Do not create a new PreScan log here; preserve the original.
    }

    // Called immediately after a scan log has been closed to begin collecting
    // post-scan activity until the next Scan/Resume command.
    func startPreScanSession(logger: Logger) async throws {
        currentMetadata = updatedMetadata()

        try createNextPreScanLogLocked()

        guard let preScanLogURL = nextPreScanLogURL else {
            throw CocoaError(.fileNoSuchFile)
        }

        try await logger.startSessionImpl(fileURL: preScanLogURL)

        if let metadata = currentMetadata {
            await writeMetadataHeader(metadata, logger: logger)
        }
    }

    func writeMetadataHeader(
        _ metadata: Metadata,
        logger: Logger
    ) async {

        await logger.infoImpl("════════════════════════════════════════")
        await logger.infoImpl("PID Hunter v\(metadata.appVersion)")
        await logger.infoImpl("Session        : \(Self.sessionFormatter.string(from: sessionStartDate ?? .now))")
        await logger.infoImpl("Mode           : \(metadata.mode?.rawValue ?? "Unknown")")
        await logger.infoImpl("Header         : \(metadata.header ?? "Unknown")")
        await logger.infoImpl("Search Engine  : \(metadata.searchEngine?.rawValue ?? "Unknown")")
        await logger.infoImpl("Request Delay  : \(metadata.requestDelay.map { "\(Int($0 * 1000)) ms" } ?? "Unknown")")
        await logger.infoImpl("Timeout        : \(metadata.requestTimeout.map { "\(Int($0 * 1000)) ms" } ?? "Unknown")")
        await logger.infoImpl("Auto Preflight : \(metadata.autoPreflight.map { $0 ? "ON" : "OFF" } ?? "Unknown")")
        await logger.infoImpl("Debug Logging  : \(metadata.debugLogging.map { $0 ? "ON" : "OFF" } ?? "Unknown")")
        await logger.infoImpl("════════════════════════════════════════")
    }

    func writeSummary(
        _ summary: Summary,
        logger: Logger
    ) async {

        await logger.infoImpl("════════ Session Summary ════════")
        await logger.infoImpl(String(format: "Elapsed   : %.1f s", summary.elapsedTime))
        await logger.infoImpl("Requests  : \(summary.requests)")
        await logger.infoImpl("Responses : \(summary.responses)")
        await logger.infoImpl("Positive  : \(summary.positives)")
        await logger.infoImpl("Negative  : \(summary.negatives)")
        await logger.infoImpl("Partial   : \(summary.partials)")
        await logger.infoImpl("Timeouts  : \(summary.timeouts)")
        await logger.infoImpl("══════════════════════════════════")
    }

    func closeCurrentLog(logger: Logger) async throws {
        guard isLoggingSessionActive else { return }

        await logger.finishSessionImpl()
    }

    func endLoggingSession() {
        if let nextPreScanLogURL,
           fileManager.fileExists(atPath: nextPreScanLogURL.path) {
            // Keep the last active log inside the session folder. Do not delete or move it here.
        }
        isLoggingSessionActive = false
        sessionFolderURL = nil
        nextPreScanLogURL = nil
        currentMetadata = nil
        sessionStartDate = nil
    }


    private static let sessionFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
}
