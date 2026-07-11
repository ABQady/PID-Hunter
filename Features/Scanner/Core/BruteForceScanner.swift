//
//  BruteForceScanner.swift
//  PIDHunter by Ahmed AlQady
//
import Foundation
import SwiftUI
struct ScanResult: Codable, Identifiable {

    var id: String {
        "\(header)|\(request)|\(response)"
    }
    let header: String
    let mode: String
    let pid: String
    let request: String
    let response: String
}

struct ScanStatus {
    var progress = 0.0
    var currentRequest = ""
    var successCount = 0
    var isScanning = false
}

struct ScanConfiguration {
    let mode: OBDMode
    let pidWidth: Int
    let startPID: Int
    let endPID: Int
    let header: String
}

@MainActor
final class ScanSession {
    var results: [ScanResult] = []
    var seen = Set<String>()
    var currentPID = 0
    var searchStrategy: any SearchStrategy = SequentialSearchStrategy(start: 0, end: 0)
}

@MainActor
final class BruteForceScanner: ObservableObject {
    static let shared = BruteForceScanner()
    
    @Published private(set) var results: [ScanResult] = []
    @Published var delayMs: Double = 100
    @Published private(set) var scanStatus = ScanStatus()
    @Published private(set) var statistics = SearchEngineStatistics()

    @AppStorage("selectedSearchEngine")
    private var selectedSearchEngine = SearchEngineType.sequential.rawValue

    var searchEngine: SearchEngineType {
        SearchEngineType(rawValue: selectedSearchEngine) ?? .sequential
    }
    
    @AppStorage("requestTimeout")
    private var requestTimeout = 2.0

    @AppStorage("enableAutoPreflight")
    private var enableAutoPreflight = true

    @AppStorage("maxConsecutiveTimeouts")
    private var maxConsecutiveTimeouts = 15
    
    private var shouldStop = false
    private let session = ScanSession()
    
    private let requestExecutor = RequestExecutor()
    @inline(__always)
    private var stats: ScanStatistics {
        ScanStatistics.shared
    }
    @inline(__always)
    private func applyDelay() async {
        guard delayMs > 0 else { return }
        try? await Task.sleep(for: .milliseconds(Int(delayMs)))
    }
    
    private let persistence = ScanPersistence.shared

    var hasResumePoint: Bool {
        persistence.hasResumePoint
    }
    
    private func scanRuntimeRequests(
        mode: OBDMode,
        context: ScanLauncher.ScanContext
    ) async {
        guard !scanStatus.isScanning else {
            Logger.shared.warning("Scan already running")
            return
        }

        beginScan()

        defer {
            if shouldStop {
                finishScan(completed: false)
            } else {
                stats.complete()
                finishScan(completed: true)
            }
        }

        guard await ensureConnection(header: context.header) else {
            return
        }

        do {
            try await ELM327.shared.setHeader(context.header)
        } catch {
            Logger.shared.error("Failed to set header \(context.header): \(error)")
            return
        }

        let requests = BikeKnowledgeFilter.buildQueue(
            for: mode,
            profile: BikeProfileManager.shared.currentProfile
        )

        stats.begin(totalRequests: requests.count)

        var completed = 0

        for request in requests {
            if shouldStop { break }

            await scanSingleRequest(
                mode: mode,
                request: request,
                context: context
            )

            completed += 1
            updateProgress(done: completed, total: requests.count)
        }
    }

    private func scanSingleRequest(
        mode: OBDMode,
        request: String,
        context: ScanLauncher.ScanContext
    ) async {
        guard await ensureConnection(header: context.header) else {
            return
        }

        scanStatus.currentRequest = request

        var consecutiveTimeouts = 0

        let requestContext = RequestContext(
            mode: mode,
            pid: 0,
            header: context.header,
            retryCount: 0,
            searchEngine: .sequential
        )

        switch await requestExecutor.execute(
            request: request,
            context: requestContext,
            timeout: requestTimeout
        ) {
        case .success(let response, let classification, let latency):
            processSuccessfulResponse(
                response,
                classification: classification,
                latency: latency,
                mode: mode,
                request: request,
                pid: 0,
                header: context.header,
                consecutiveTimeouts: &consecutiveTimeouts
            )
            await applyDelay()

        case .timeout:
            await processTimeout(
                pid: 0,
                consecutiveTimeouts: &consecutiveTimeouts
            )
            if shouldStop {
                finishScan(completed: false)
                return
            }

        case .connectionLost:
            guard await handleConnectionLoss(
                header: context.header,
                consecutiveTimeouts: &consecutiveTimeouts
            ) else {
                finishScan(completed: false)
                return
            }
        }
    }

    // MARK: - Runtime Request Scans

    func scanFixedCommands(
        mode: OBDMode,
        context: ScanLauncher.ScanContext
    ) async {
        await scanRuntimeRequests(
            mode: mode,
            context: context
        )
    }

    func scanInfoType(
        mode: OBDMode,
        context: ScanLauncher.ScanContext
    ) async {
        await scanRuntimeRequests(
            mode: mode,
            context: context
        )
    }
    
    private func beginScan() {
        shouldStop = false
        statistics.reset()

        scanStatus.successCount =
            persistence.hasResumePoint
            ? session.results.count
            : 0
        
        scanStatus.isScanning = true
        scanStatus.progress = 0
        scanStatus.currentRequest = ""
    }
    
    private func finishScan(completed: Bool) {
        scanStatus.isScanning = false
        scanStatus.currentRequest = ""
        
        RequestOutcomeProcessor.shared.flushProfile()
        
        Logger.shared.info(
            "Requests: \(statistics.requestsSent), Success: \(statistics.successfulResponses), Failures: \(statistics.failedResponses)"
        )

        if completed {
            scanStatus.progress = 1.0
            persistence.clearResumePoint(session: session)
            // persistence.refreshResumeAvailability() // Removed as ScanPersistence refreshes internally
        } else {
            persistence.saveResumePoint(
                session: session,
                statistics: statistics,
                scanStatistics: stats,
                force: true
            )
            persistence.saveResults(session.results)
            // persistence.refreshResumeAvailability() // Removed as ScanPersistence refreshes internally
        }

        shouldStop = false
    }
    
    func startFresh() {

        shouldStop = false
        scanStatus.progress = 0
        scanStatus.currentRequest = ""
        scanStatus.isScanning = false
        
        session.currentPID = 0
        session.searchStrategy.reset()

        session.results.removeAll()
        session.seen.removeAll()
        results = session.results
        scanStatus.successCount = 0

        persistence.clearSavedResults()
        Logger.shared.clear()
        statistics.reset()
        ScanStatistics.shared.reset()
        persistence.clearResumePoint(session: session)
        scanStatus.currentRequest = ""
    }
    
    // hasResumePoint is now a published property, no longer a computed property.
    
    private func clearResults() {
        session.results.removeAll()
        session.seen.removeAll()
        results = session.results
        scanStatus.successCount = 0

        persistence.clearSavedResults()
    }

    private func ensureConnection(header: String) async -> Bool {
        if BluetoothManager.shared.isConnected {
            return true
        }

        Logger.shared.warning("🔄 Reconnecting...")

        await BluetoothManager.shared.reconnect()
        try? await Task.sleep(for: .milliseconds(500))
        
        let ok: Bool
        if enableAutoPreflight {
            ok = await Preflight.shared.run(header: header)
        } else {
            ok = BluetoothManager.shared.isConnected
        }

        guard ok else {
            Logger.shared.error("❌ Reconnect failed")
            return false
        }

        do {
            try await ELM327.shared.setHeader(header)
        } catch {
            Logger.shared.error("Failed to restore header \(header): \(error)")
            return false
        }
        
        return true
    }

    private func handleTimeout() async {
        Logger.shared.warning("⏰ Request timeout")

        guard delayMs > 0 else { return }

        try? await Task.sleep(for: .milliseconds(Int(delayMs)))
    }
    
    private func resetTimeoutCounter(_ counter: inout Int) {
        counter = 0
    }

    @discardableResult
    private func handleConnectionLoss(header: String, consecutiveTimeouts: inout Int) async -> Bool {
        Logger.shared.error("Connection lost")

        guard await ensureConnection(header: header) else {
            return false
        }
        resetTimeoutCounter(&consecutiveTimeouts)

        return true
    }

    private func updateProgress(done: Int, total: Int) {
        scanStatus.progress = Double(done) / Double(total)
        stats.totalRequests = total
        
        persistence.saveResumePoint(
            session: session,
            statistics: statistics,
            scanStatistics: stats
        )
    }

    private func makeRequest(mode: OBDMode, pid: String) -> String {
        mode.rawValue + pid
    }

    // MARK: - Response Processing
    // TODO: Move statistics updates into a dedicated ScanResultProcessor once learning and analytics are fully separated.
    private func processSuccessfulResponse(
        _ response: ELMResponse,
        classification: SearchResult,
        latency: Double,
        mode: OBDMode,
        request: String,
        pid: UInt16,
        header: String,
        consecutiveTimeouts: inout Int
    ) {
        let outcome = RequestOutcomeProcessor.shared.handleSuccess(
            response: response,
            classification: classification,
            latency: latency,
            mode: mode,
            request: request,
            consecutiveTimeouts: &consecutiveTimeouts
        )

        guard case .success(let processing) = outcome else {
            assertionFailure("Unexpected RequestOutcome from handleSuccess")
            return
        }

        statistics.record(
            result: classification,
            latency: latency
        )
        
        guard processing.profileUpdated else {
            Logger.shared.warning("Bike Profile update skipped")
            return
        }

        guard processing.shouldPersist else {
            return
        }

        let pidString = mode.scanCapability.pidWidth == 2
            ? String(format: "%02X", pid)
            : String(format: "%04X", pid)

        if appendResponse(
            header: header,
            mode: mode.rawValue,
            pid: pid == 0 ? "" : pidString,
            request: request,
            response: response,
            classification: classification
        ) {
            // statistics.recordDiscovery() // No longer tracked
        }

        session.searchStrategy.registerResult(
            pid: pid,
            result: classification,
            latency: latency
        )
    }

    // MARK: - Timeout Processing
    private func processTimeout(
        pid: UInt16,
        consecutiveTimeouts: inout Int
    ) async {
        let requestOutcome = RequestOutcomeProcessor.shared.handleTimeout(
            timeout: requestTimeout,
            consecutiveTimeouts: &consecutiveTimeouts,
            maxConsecutiveTimeouts: maxConsecutiveTimeouts
        )

        guard case .timeout(let outcome) = requestOutcome else {
            assertionFailure("Unexpected RequestOutcome from handleTimeout")
            return
        }

        statistics.record(
            result: SearchResult.timeout,
            latency: requestTimeout
        )

        if outcome.shouldAbortScan {
            Logger.shared.error(
                "Consecutive timeout limit (\(maxConsecutiveTimeouts)) reached. Stopping scan."
            )
            stats.complete()
            shouldStop = true
            return
        }

        session.searchStrategy.registerResult(
            pid: pid,
            result: .timeout,
            latency: requestTimeout
        )

        await handleTimeout()
    }
    
    
    func stop() {
        shouldStop = true
        scanStatus.currentRequest = "Stopping..."
        stats.complete()
    }
    
    // MARK: - Search Strategy Preparation
    private func prepareStrategy(startPID: Int, endPID: Int, resumePID: Int) {
        session.searchStrategy = SearchEngineFactory.make(
            type: searchEngine,
            start: UInt16(startPID),
            end: UInt16(endPID)
        )
        session.currentPID = resumePID
        Logger.shared.info("Search Engine = \(searchEngine)")
        Logger.shared.info(
            "Scanner using \(session.searchStrategy.engineType)"
        )
        while let pid = session.searchStrategy.nextPID(), pid < UInt16(resumePID) {
            // Advance the strategy until it reaches the resume PID.
        }
    }

    // MARK: - PID Scan Engine
    
    private func restoreScanState(
        configuration: ScanConfiguration
    ) {
        persistence.loadResumePoint(
            into: session,
            scanStatistics: stats
        )

        if session.currentPID < configuration.startPID ||
            session.currentPID > configuration.endPID {
            session.currentPID = configuration.startPID
        }

        if session.currentPID == configuration.startPID {
            clearResults()
        } else {
            session.results = persistence.loadResults()
            results = session.results
        }

        scanStatus.successCount = session.results.count
    }
    
    private func prepareStatistics(
        configuration: ScanConfiguration
    ) -> (total: Int, done: Int) {

        let count =
            configuration.endPID -
            configuration.startPID + 1

        let total = count

        let done =
            session.currentPID - configuration.startPID

        if session.currentPID == configuration.startPID {
            stats.begin(totalRequests: total)
        } else {
            stats.totalRequests = total
            if stats.startedAt == nil {
                stats.start()
            }
        }

        return (total, done)
    }
    

    // This method contains the complete PID brute-force execution pipeline.
    // It is intentionally isolated so it can be moved into PIDScanEngine
    // during the next refactoring step without changing behavior.
    private func executePIDScan(
        configuration: ScanConfiguration
    ) async {
        defer {
            if shouldStop {
                finishScan(completed: false)
            } else {
                stats.complete()
                finishScan(completed: true)
            }
        }

        beginScan()
        
        restoreScanState(configuration: configuration)
        
        prepareStrategy(
            startPID: configuration.startPID,
            endPID: configuration.endPID,
            resumePID: session.currentPID
        )

        do {
            try await ELM327.shared.setHeader(configuration.header)
        } catch {
            Logger.shared.error("Failed to set header \(configuration.header): \(error)")
            return
        }

        var progress = prepareStatistics(configuration: configuration)
        var consecutiveTimeouts = 0

        await scanHeader(
            header: configuration.header,
            configuration: configuration,
            total: progress.total,
            done: &progress.done,
            consecutiveTimeouts: &consecutiveTimeouts
        )

        if shouldStop {
            return
        }
    }

    
    /////////////////////////////////////////////
    // MARK: - PID Header Execution
    private func scanHeader(
        header: String,
        configuration: ScanConfiguration,
        total: Int,
        done: inout Int,
        consecutiveTimeouts: inout Int
    ) async {
        while let nextPID = session.searchStrategy.nextPID() {
            session.currentPID = Int(nextPID)
            if shouldStop {
                return
            }

            let pid = String(format: "%0*X", configuration.pidWidth, Int(nextPID))
            let req = makeRequest(mode: configuration.mode, pid: pid)
            scanStatus.currentRequest = req

            if !BluetoothManager.shared.isConnected {
                guard await ensureConnection(header: header) else {
                    continue
                }
            }

            let context = RequestContext(
                mode: configuration.mode,
                pid: nextPID,
                header: header,
                retryCount: 0,
                searchEngine: session.searchStrategy.engineType
            )
            switch await requestExecutor.execute(
                request: req,
                context: context,
                timeout: requestTimeout
            ) {
            case .success(let response, let classification, let latency):
                processSuccessfulResponse(
                    response,
                    classification: classification,
                    latency: latency,
                    mode: configuration.mode,
                    request: req,
                    pid: nextPID,
                    header: header,
                    consecutiveTimeouts: &consecutiveTimeouts
                )
                await applyDelay()
            case .timeout:
                await processTimeout(
                    pid: nextPID,
                    consecutiveTimeouts: &consecutiveTimeouts
                )
                if shouldStop {
                    return
                }
            case .connectionLost:
                guard await handleConnectionLoss(header: header, consecutiveTimeouts: &consecutiveTimeouts) else {
                    continue
                }
                continue
            }
            done += 1
            updateProgress(done: done, total: total)

            if shouldStop {
                scanStatus.currentRequest = ""
                return
            }
        }
    }

    func scan(
        mode: OBDMode,
        header: String,
        startPID: UInt16? = nil,
        endPID: UInt16? = nil
    ) {
        guard !scanStatus.isScanning else {
            Logger.shared.warning("Scan already running")
            return
        }
        shouldStop = false
        session.searchStrategy.reset()
        
        let configuration = ScanConfiguration(
            mode: mode,
            pidWidth: mode.scanCapability.pidWidth,
            startPID: startPID.map(Int.init) ?? mode.pidRange?.lowerBound ?? 0,
            endPID: endPID.map(Int.init) ?? mode.pidRange?.upperBound ?? 0,
            header: header
        )

        Logger.shared.info("Search engine: \(searchEngine)")
        Logger.shared.info(
            "Starting \(mode.rawValue) scan using header \(header)"
        )
        
        Task {
            await executePIDScan(
                configuration: configuration
            )
        }
    }
    
    @discardableResult
    func appendResponse(
        header: String,
        mode: String,
        pid: String,
        request: String,
        response: ELMResponse,
        classification: SearchResult
    ) -> Bool {
        guard !response.raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        guard classification.shouldPersist else {
            return false
        }

        let result = ScanResult(
            header: header,
            mode: mode,
            pid: pid,
            request: request,
            response: response.raw
        )
        let key = result.id

        guard !session.seen.contains(key) else {
            return false
        }

        session.seen.insert(key)
        session.results.append(result)
        //        session.results.sort {
        //            ($0.header, $0.mode, $0.request) <
        //            ($1.header, $1.mode, $1.request)
        //        }
        results = session.results

        scanStatus.successCount = session.results.count
        Logger.shared.success("✅ Stored response \(request) -> \(response.raw)")
        // Persist only after the in-memory model and published UI state are synchronized.
        persistence.saveResults(session.results)

        return true
    }
    
    func exportJSON() throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data =
        try encoder.encode(results)
        let url =
        FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "found_pids.json"
            )
        try data.write(to: url)
        return url
    }
}
