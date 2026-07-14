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

struct PartialFrame: Codable, Identifiable {
    var id: String {
            "\(header)|\(mode)|\(request)"
        }
    let header: String
    let mode: String
    let pid: String
    let request: String
    let rawResponse: String
    var timestamp = Date()
    var attempts = 1
    var retrySucceeded = false
    var resolution: PartialFrameResolution = .pending
}

enum PartialFrameResolution: String, Codable {
    case pending
    case confirmedPositive
    case confirmedNegative
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
final class BruteForceScanner: ObservableObject {
    static let shared = BruteForceScanner()
    
    @Published private(set) var results: [ScanResult] = []
    @Published var delayMs: Double = 100
    @Published private(set) var scanStatus = ScanStatus()
    @Published private(set) var session = ScanSession()
    @Published private(set) var statistics = SearchEngineStatistics()
    @Published private(set) var partialFrames: [PartialFrame] = []
    @Published private(set) var partialFrameCount = 0

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

    @AppStorage("partialFrameRetryCount")
    private var partialFrameRetryCount = 3
    
    private var shouldStop = false
    
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

        guard await ensureConnection(header: context.header, mode: mode) else {
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
        guard await ensureConnection(header: context.header, mode: mode) else {
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
                mode: mode,
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
    
    // MARK: - Scan Lifecycle
    private func beginScan() {
        shouldStop = false
        statistics.reset()

        // Runtime state only. Logger session management is intentionally handled outside
        // the scanner so PreScan and Scan remain separate sessions.

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
        
        // Flush all pending profile mutations before any session finalization.
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
        session.header = ""
        session.mode = nil
        session.startPID = 0
        session.endPID = 0

        session.searchStrategy.reset()

        session.results.removeAll()
        partialFrames.removeAll()
        partialFrameCount = 0
        
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
        partialFrames.removeAll()
        partialFrameCount = 0
        session.seen.removeAll()
        results = session.results
        scanStatus.successCount = 0

        persistence.clearSavedResults()
    }

    private func ensureConnection(
        header: String,
        mode: OBDMode
    ) async -> Bool {
        if BluetoothManager.shared.isConnected {
            return true
        }

        Logger.shared.warning("🔄 Reconnecting...")

        await BluetoothManager.shared.reconnect()
        try? await Task.sleep(for: .milliseconds(500))

        let ok: Bool
        if enableAutoPreflight {
            ok = await Preflight.shared.run(
                header: header,
                mode: mode
            )
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
    private func handleConnectionLoss(
        header: String,
        mode: OBDMode,
        consecutiveTimeouts: inout Int
    ) async -> Bool {
        Logger.shared.error("Connection lost")

        guard await ensureConnection(header: header, mode: mode) else {
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

    /// Formats a PID as an uppercase hex string with the correct width for the given mode.
    @inline(__always)
    private func formattedPID(_ pid: UInt16, for mode: OBDMode) -> String {
        let width = mode.scanCapability.pidWidth
        return String(format: "%0*X", width, pid)
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
        // Move partial frame handling before handleSuccess
        statistics.record(
            result: classification,
            latency: latency
        )
        switch classification {
        case .positive:
            stats.recordPositiveResponse()

        case .negative:
            stats.recordNegativeResponse()

        case .noData:
            stats.recordNoData()

        case .partialFrame:
            stats.recordPartialFrame()

        case .adapter, .unknown:
            stats.recordBusError()

        case .timeout:
            stats.recordTimeout()
        }

        if case .partialFrame = classification {
            let pidString = formattedPID(pid, for: mode)

            partialFrames.append(
                PartialFrame(
                    header: header,
                    mode: mode.rawValue,
                    pid: pid == 0 ? "" : pidString,
                    request: request,
                    rawResponse: response.raw
                )
            )
            partialFrameCount = partialFrames.count

            session.searchStrategy.registerResult(
                pid: pid,
                result: classification,
                latency: latency
            )

            Logger.shared.warning("🟡 Partial frame detected: \(request) -> \(response.raw)")
            return
        }

        let outcome = RequestOutcomeProcessor.shared.handleSuccess(
            response: response,
            classification: classification,
            latency: latency,
            mode: mode,
            request: request,
            requestHeader: header,
            consecutiveTimeouts: &consecutiveTimeouts
        )

        guard case .success(let processing) = outcome else {
            assertionFailure("Unexpected RequestOutcome from handleSuccess")
            return
        }

        guard processing.shouldPersist else {
            return
        }

        // Persist scanner discoveries into the scan session after the bike profile has already been updated.
        let pidString = formattedPID(pid, for: mode)

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

        // Feed the search engine regardless of persistence so adaptive strategies learn from every outcome.
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
        stats.recordTimeout()

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

    // MARK: - Partial Frame Retry Processing


    private func processRetryResult(
        _ result: PartialFrameRetryResult,
        consecutiveTimeouts: inout Int
    ) async {
        guard let index = partialFrames.firstIndex(where: {
            $0.id == result.frame.id
        }) else {
            Logger.shared.warning("Retry result ignored; frame no longer exists: \(result.frame.request)")
            return
        }

        let frame = result.frame
        let pid = UInt16(frame.pid, radix: 16) ?? 0
        let mode = OBDMode(rawValue: frame.mode) ?? .mode01

        switch result.outcome {
        case .success(let response, let classification, let latency):
            // Only a received response is a completed retry attempt. The retry
            // engine never mutates this bookkeeping.
            partialFrames[index].attempts += 1
            statistics.record(
                result: classification,
                latency: latency
            )
            resetTimeoutCounter(&consecutiveTimeouts)

            switch classification {
            case .positive:

                partialFrames[index].retrySucceeded = true
                partialFrames[index].resolution = .confirmedPositive

                let outcome = RequestOutcomeProcessor.shared.recordRetryPositive(
                    response: response,
                    classification: classification,
                    latency: latency,
                    mode: mode,
                    requestHeader: frame.header,
                    request: frame.request,
                    consecutiveTimeouts: &consecutiveTimeouts
                )

                guard case .success(let processing) = outcome else {
                    return
                }

                if processing.shouldPersist {
                    _ = appendResponse(
                        header: frame.header,
                        mode: frame.mode,
                        pid: frame.pid,
                        request: frame.request,
                        response: response,
                        classification: classification
                    )
                }

                session.searchStrategy.registerResult(
                    pid: pid,
                    result: classification,
                    latency: latency
                )

                Logger.shared.success("✅ Partial retry confirmed positive: \(frame.request)")

            case .partialFrame:
                session.searchStrategy.registerResult(
                    pid: pid,
                    result: classification,
                    latency: latency
                )
                ScanStatistics.shared.recordPartialFrame()
                Logger.shared.warning("🟡 Partial retry still incomplete: \(frame.request)")

            case .negative, .noData:
                partialFrames[index].resolution = .confirmedNegative

                _ = RequestOutcomeProcessor.shared.recordConfirmedNegative(
                    response: response,
                    classification: classification,
                    latency: latency,
                    mode: mode,
                    requestHeader: frame.header,
                    request: frame.request,
                    consecutiveTimeouts: &consecutiveTimeouts
                )

                session.searchStrategy.registerResult(
                    pid: pid,
                    result: classification,
                    latency: latency
                )

                Logger.shared.info("🔴 Partial retry confirmed negative: \(frame.request)")

            case .timeout, .adapter, .unknown:
                Logger.shared.warning("Retry returned \(classification) for \(frame.request)")
            }

        case .timeout:
            Logger.shared.warning("⏱️ Partial retry timed out: \(frame.request)")

        case .connectionLost:
            Logger.shared.error("📡 Partial retry lost connection: \(frame.request)")
        }
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
        
        // Resume should only validate against the persisted session selected by
        // ScanLauncher. At this point configuration already contains the
        // restored header/mode. Only restart if there is no valid resume point.
        if !persistence.hasResumePoint {
            session.currentPID = configuration.startPID
            clearResults()
        }

        if session.currentPID == configuration.startPID {
            clearResults()
        } else {
            session.results = persistence.loadResults()
            results = session.results
        }

        // Rebuild the duplicate filter after loading persisted discoveries.
        session.seen = Set(session.results.map(\.id))

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

        if !shouldStop && !partialFrames.isEmpty {
            Logger.shared.info("Retrying partial frames...")

            let retryResults = await PartialFrameRetryEngine().retryPendingFrames(
                using: requestExecutor,
                frames: partialFrames,
                makeContext: { frame in
                    RequestContext(
                        mode: OBDMode(rawValue: frame.mode) ?? configuration.mode,
                        pid: UInt16(frame.pid, radix: 16) ?? 0,
                        header: frame.header,
                        retryCount: frame.attempts,
                        searchEngine: session.searchStrategy.engineType
                    )
                },
                timeout: requestTimeout
            )

            Logger.shared.info(
                "Partial retry pass completed. \(retryResults.count) frame(s) processed."
            )

            for retryResult in retryResults {
                await processRetryResult(
                    retryResult,
                    consecutiveTimeouts: &consecutiveTimeouts
                )
            }

            partialFrameCount = partialFrames.filter {
                $0.resolution == .pending
            }.count
        }

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

            let pid = formattedPID(nextPID, for: configuration.mode)
            let req = makeRequest(mode: configuration.mode, pid: pid)
            scanStatus.currentRequest = req

            if !BluetoothManager.shared.isConnected {
                guard await ensureConnection(header: header, mode: configuration.mode) else {
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
                guard await handleConnectionLoss(
                    header: header,
                    mode: configuration.mode,
                    consecutiveTimeouts: &consecutiveTimeouts
                ) else {
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

    // MARK: - Public Scan Entry Point
    func scan(
        mode: OBDMode,
        header: String,
        startPID: UInt16? = nil,
        endPID: UInt16? = nil
    ) async {
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
        
        // Persist session metadata for Resume Session.
        session.header = configuration.header
        session.mode = configuration.mode
        session.startPID = configuration.startPID
        session.endPID = configuration.endPID
        
        // IMPORTANT:
        // This method must never create or promote logger sessions directly.
        // Session transitions are owned by ScanLauncher/LogSessionManager so that
        // PreScan logging is finalized before the dedicated scan log begins.
        Logger.shared.info("Search engine: \(searchEngine)")
        Logger.shared.info(
            "Starting \(mode.rawValue) scan using header \(header)"
        )

        await executePIDScan(
            configuration: configuration
        )
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
        let resultID = result.id

        guard session.seen.insert(resultID).inserted else {
            return false
        }

        session.results.append(result)
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
