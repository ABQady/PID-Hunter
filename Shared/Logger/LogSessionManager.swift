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
    private(set) var activeLogURL: URL?

    private var sessionStarted = false
    private var currentMetadata: Metadata?
    private var sessionStartDate: Date?

    var isSessionStarted: Bool {
        sessionStarted
    }
    
    private init() {}

    private func prepareActiveLogLocked() throws {

        guard let sessionFolderURL else {
            return
        }

        let filename = Self.sessionFormatter.string(from: .now) + "_PreScan.log"

        let url = sessionFolderURL
            .appendingPathComponent(filename)

        if !fileManager.fileExists(atPath: url.path) {
            fileManager.createFile(
                atPath: url.path,
                contents: nil
            )
        }

        activeLogURL = url
    }

    func beginLoggingSessionIfNeeded(
        metadata: Metadata,
        logger: Logger
    ) async throws {

        guard !sessionStarted else {
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

        let folderName = Self.sessionFormatter.string(from: .now)

        let sessionFolder = logsFolder
            .appendingPathComponent(folderName, isDirectory: true)

        try fileManager.createDirectory(
            at: sessionFolder,
            withIntermediateDirectories: true
        )

        sessionFolderURL = sessionFolder
        sessionStartDate = .now
        sessionStarted = true

        try prepareActiveLogLocked()

        guard let activeLogURL else {
            throw CocoaError(.fileNoSuchFile)
        }

        currentMetadata = metadata
        try await logger.startSessionImpl(fileURL: activeLogURL)
        await writeMetadataHeader(metadata, logger: logger)
    }

    func prepareActiveLog() throws {
        try prepareActiveLogLocked()
    }

    var hasActiveSession: Bool {
        sessionStarted
    }

    var currentActiveLogURL: URL? {
        activeLogURL
    }

    struct Metadata {
        let appVersion: String
        let mode: OBDMode
        let header: String
        let searchEngine: SearchEngineType
        let requestDelay: Double
        let requestTimeout: Double
        let autoPreflight: Bool
        let debugLogging: Bool
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

    func archiveActiveLog(as filename: String) throws {

        guard
            let sessionFolderURL,
            let activeLogURL
        else {
            return
        }

        let destination = sessionFolderURL
            .appendingPathComponent(filename)

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        try fileManager.moveItem(
            at: activeLogURL,
            to: destination
        )

        try prepareActiveLogLocked()
    }

    func promoteCurrentSession(
        mode: OBDMode,
        header: String,
        searchEngine: SearchEngineType,
        logger: Logger
    ) async throws {

        let filename = LogFileNaming.makeFilename(
            mode: mode,
            header: header,
            searchEngine: searchEngine
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

        await logger.finishSessionImpl()
        // endLoggingSession() -- removed as per instructions

        try archiveActiveLog(as: filename)

        guard let activeLogURL else {
            throw CocoaError(.fileNoSuchFile)
        }

        try await logger.startSessionImpl(fileURL: activeLogURL)
        sessionStarted = true

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
        await logger.infoImpl("Mode           : \(metadata.mode.rawValue)")
        await logger.infoImpl("Header         : \(metadata.header)")
        await logger.infoImpl("Search Engine  : \(metadata.searchEngine.rawValue)")
        await logger.infoImpl(String(format: "Request Delay  : %.0f ms", metadata.requestDelay * 1000))
        await logger.infoImpl(String(format: "Timeout        : %.0f ms", metadata.requestTimeout * 1000))
        await logger.infoImpl("Auto Preflight : \(metadata.autoPreflight ? "ON" : "OFF")")
        await logger.infoImpl("Debug Logging  : \(metadata.debugLogging ? "ON" : "OFF")")
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

    func endLoggingSession() {
        sessionStarted = false
        sessionFolderURL = nil
        activeLogURL = nil
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
