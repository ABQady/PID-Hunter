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

@MainActor
final class BruteForceScanner: ObservableObject {
    static let shared = BruteForceScanner()
    
    @Published private(set) var results: [ScanResult] = []
    @Published var delayMs: Double = 100
    @Published private(set) var scanStatus = ScanStatus()
    @Published private(set) var statistics = SearchStatistics()
    @Published private(set) var hasResumePoint = false
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
    private var seen = Set<String>()
    
    private var currentHeaderIndex = 0
    private var currentPID = 0
    private var searchStrategy: any SearchStrategy = SequentialSearchStrategy(
        start: 0,
        end: 0
    )
    
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
    
    
    private func saveResumePoint(force: Bool = false) {
        if !force && (currentPID % 10 != 0) {
            return
        }

        let defaults = UserDefaults.standard
        defaults.set(currentHeaderIndex, forKey: "resumeHeader")
        defaults.set(currentPID, forKey: "resumePID")

        let requestStats = statistics
        
        defaults.set(requestStats.requestsSent, forKey: "resumeRequestsSent")
        defaults.set(requestStats.successfulResponses + requestStats.failedResponses, forKey: "resumeResponses")
        let stats = ScanStatistics.shared
        defaults.set(stats.positiveResponses, forKey: "resumePositiveResponses")
        defaults.set(stats.negativeResponses, forKey: "resumeNegativeResponses")
        defaults.set(stats.timeouts, forKey: "resumeTimeouts")
        defaults.set(stats.startedAt, forKey: "resumeStartedAt")

        refreshResumeAvailability()
    }
    
    private func beginScan() {
        shouldStop = false
        requestExecutor.resetStatistics()
        statistics.reset()
        scanStatus.isScanning = true
        scanStatus.progress = 0
        scanStatus.currentRequest = ""
    }
    
    private func finishScan(completed: Bool) {
        scanStatus.isScanning = false
        scanStatus.currentRequest = ""

        Logger.shared.info(
            "Requests: \(statistics.requestsSent), Success: \(statistics.successfulResponses), Failures: \(statistics.failedResponses)"
        )

        if completed {
            scanStatus.progress = 1.0
            clearResumePoint()
        } else {
            saveResumePoint(force: true)
            saveResults()
        }

        shouldStop = false
    }

    private func loadResumePoint() {
        let defaults = UserDefaults.standard

        currentHeaderIndex = defaults.object(forKey: "resumeHeader") as? Int ?? 0
        currentPID = defaults.object(forKey: "resumePID") as? Int ?? 0

        let stats = ScanStatistics.shared
        requestExecutor.resetStatistics()
        // Remove assignments to stats.requestsSent and stats.responses
        stats.positiveResponses = defaults.object(forKey: "resumePositiveResponses") as? Int ?? 0
        stats.negativeResponses = defaults.object(forKey: "resumeNegativeResponses") as? Int ?? 0
        stats.timeouts = defaults.object(forKey: "resumeTimeouts") as? Int ?? 0
        stats.startedAt = defaults.object(forKey: "resumeStartedAt") as? Date
        stats.finishedAt = nil

        refreshResumeAvailability()
    }

    private func refreshResumeAvailability() {
        let defaults = UserDefaults.standard
        hasResumePoint = defaults.object(forKey: "resumeHeader") != nil &&
                         defaults.object(forKey: "resumePID") != nil
    }
    
    private func saveResults() {
        if let data = try? JSONEncoder().encode(results) {
            UserDefaults.standard.set(data, forKey: "savedResults")
        }
    }

    private func loadResults() {
        guard
            let data = UserDefaults.standard.data(forKey: "savedResults"),
            let saved = try? JSONDecoder().decode([ScanResult].self, from: data)
        else {
            return
        }

        results = saved
        seen = Set(saved.map { "\($0.header)|\($0.request)|\($0.response)" })
        scanStatus.successCount = saved.count
        let total = ScanStatistics.shared.totalRequests
        scanStatus.progress = total > 0
            ? Double(statistics.requestsSent) / Double(total)
            : 0
    }
    func startFresh() {

        shouldStop = false
        scanStatus.progress = 0
        scanStatus.currentRequest = ""
        scanStatus.isScanning = false
        
        currentHeaderIndex = 0
        currentPID = 0
        searchStrategy.reset()

        results.removeAll()
        seen.removeAll()
        scanStatus.successCount = 0

        UserDefaults.standard.removeObject(forKey: "savedResults")
        Logger.shared.clear()
        ScanStatistics.shared.reset()
        requestExecutor.resetStatistics()
        clearResumePoint()
    }
    
    func clearResumePoint() {
        currentHeaderIndex = 0
        currentPID = 0
        searchStrategy.reset()
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "resumeHeader")
        defaults.removeObject(forKey: "resumePID")
        defaults.removeObject(forKey: "resumeRequestsSent")
        defaults.removeObject(forKey: "resumeResponses")
        defaults.removeObject(forKey: "resumePositiveResponses")
        defaults.removeObject(forKey: "resumeNegativeResponses")
        defaults.removeObject(forKey: "resumeTimeouts")
        defaults.removeObject(forKey: "resumeStartedAt")
        refreshResumeAvailability()
    }
    
    // hasResumePoint is now a published property, no longer a computed property.
    
    private func clearResults() {
        results.removeAll()
        seen.removeAll()
        scanStatus.successCount = 0

        UserDefaults.standard.removeObject(forKey: "savedResults")
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

        ELM327.shared.setHeader(header)
        try? await Task.sleep(for: .milliseconds(100))
        
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
        saveResumePoint()
        scanStatus.progress = Double(done) / Double(total)
    }

    private func makeRequest(mode: OBDMode, pid: String) -> String {
        mode.rawValue + pid
    }

    // TODO: Move statistics updates into a dedicated ScanResultProcessor once learning and analytics are fully separated.
    private func processSuccessfulResponse(
        _ response: ELMResponse,
        latency: Double,
        header: String,
        mode: OBDMode,
        request: String,
        pid: UInt16,
        consecutiveTimeouts: inout Int
    ) {
        let searchResult = requestExecutor.classify(response)
        switch response.type {
            case .mode01, .mode21, .mode22:
                stats.recordPositiveResponse()
            case .negative:
                stats.recordNegativeResponse()
            case .noData:
                stats.recordNoData()
            case .busError:
                stats.recordBusError()
            default:
                break
            }

        statistics.record(result: searchResult, latency: latency)

        resetTimeoutCounter(&consecutiveTimeouts)

        if appendResponse(
            header: header,
            mode: mode.rawValue,
            pid: String(request.dropFirst(2)),
            request: request,
            response: response.raw
        ) {
            statistics.recordDiscovery()
        }

        searchStrategy.registerResult(
            pid: pid,
            result: searchResult,
            latency: latency
        )
    }

    private func processTimeout(
        pid: UInt16,
        consecutiveTimeouts: inout Int
    ) async {
        statistics.record(result: .timeout, latency: requestTimeout)
        stats.recordTimeout()
        
        consecutiveTimeouts += 1

        if consecutiveTimeouts >= maxConsecutiveTimeouts {
            Logger.shared.error("Consecutive timeout limit (\(maxConsecutiveTimeouts)) reached. Stopping scan.")
            stats.complete()
            shouldStop = true
            return
        }

        searchStrategy.registerResult(
            pid: pid,
            result: .timeout,
            latency: requestTimeout
        )

        await handleTimeout()
    }
    
    var headers = [
        "81F111",
        "80F111",
        "82F111"
    ]
    
    func stop() {
        shouldStop = true
        stats.complete()
    }
    
    // MARK: - Generic Scan Implementation
    private func prepareStrategy(startPID: Int, endPID: Int, resumePID: Int) {
        searchStrategy = SearchEngineFactory.make(
            type: searchEngine,
            start: UInt16(startPID),
            end: UInt16(endPID)
        )
        currentPID = resumePID
        Logger.shared.info("Search Engine = \(searchEngine)")
        Logger.shared.info(
            "Scanner using \(searchStrategy.engineType)"
        )
        while let pid = searchStrategy.nextPID(), pid < UInt16(resumePID) {
            // Advance the strategy until it reaches the resume PID.
        }
    }

    private func scan(
        mode: OBDMode,
        startPID: Int? = nil,
        endPID: Int? = nil
    ) async {
        let pidWidth = mode.pidDigits
        let startPID = startPID ?? mode.defaultStartPID
        let endPID = endPID ?? mode.defaultEndPID
        
        // searchStrategy is now created per-header below.
        
        loadResumePoint()
        if currentHeaderIndex >= headers.count {
            currentHeaderIndex = 0
        }
        // Clamp currentPID to range
        if currentPID < startPID || currentPID > endPID {
            currentPID = startPID
        }
        // searchStrategy.seek(to: UInt16(currentPID)) is now handled per-header.

        // Clear or load results as needed
        if currentHeaderIndex == 0 && currentPID == startPID {
            clearResults()
        } else {
            loadResults()
        }

        let count = endPID - startPID + 1
        let total = headers.count * count
        var done = currentHeaderIndex * count + (currentPID - startPID)

        if currentHeaderIndex == 0 && currentPID == startPID {
            stats.begin(totalRequests: total)
        } else {
            stats.totalRequests = total
            if stats.startedAt == nil {
                stats.start()
            }
        }

        beginScan()
        var consecutiveTimeouts = 0
        let resumeHeader = UserDefaults.standard.object(forKey: "resumeHeader") as? Int

        while currentHeaderIndex < headers.count {
            let header = headers[currentHeaderIndex]
            // Recreate the strategy for each header so scanning restarts from the
            // appropriate PID on every ECU header.
            let resumePID = (currentHeaderIndex == resumeHeader)
                ? currentPID
                : startPID

            prepareStrategy(
                startPID: startPID,
                endPID: endPID,
                resumePID: resumePID
            )

            ELM327.shared.setHeader(header)
            try? await Task.sleep(for: .milliseconds(50))

            await scanHeader(
                header: header,
                mode: mode,
                pidWidth: pidWidth,
                total: total,
                done: &done,
                consecutiveTimeouts: &consecutiveTimeouts
            )

            if shouldStop {
                finishScan(completed: false)
                return
            }

            currentHeaderIndex += 1
            currentPID = startPID
            searchStrategy.reset()
            saveResumePoint()
        }
        stats.complete()
        finishScan(completed: true)
    }

    // MARK: - Header Scan
    private func scanHeader(
        header: String,
        mode: OBDMode,
        pidWidth: Int,
        total: Int,
        done: inout Int,
        consecutiveTimeouts: inout Int
    ) async {
        while let nextPID = searchStrategy.nextPID() {
            currentPID = Int(nextPID)
            if shouldStop {
                return
            }

            let pid = String(format: "%0*X", pidWidth, Int(nextPID))
            let req = makeRequest(mode: mode, pid: pid)
            scanStatus.currentRequest = req
            if !BluetoothManager.shared.isConnected {
                guard await ensureConnection(header: header) else {
                    continue
                }
                continue
            }

            let context = RequestContext(
                mode: mode,
                pid: nextPID,
                header: header,
                retryCount: 0,
                searchEngine: searchStrategy.engineType
            )
            switch await requestExecutor.execute(
                request: req,
                context: context,
                timeout: requestTimeout
            ) {
            case .success(let response, let latency):
                processSuccessfulResponse(
                    response,
                    latency: latency,
                    header: header,
                    mode: mode,
                    request: req,
                    pid: nextPID,
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
        }
    }

    func scan(
        mode: OBDMode,
        startPID: UInt16? = nil,
        endPID: UInt16? = nil
    ) {
        Task {
            await scan(
                mode: mode,
                startPID: startPID.map(Int.init),
                endPID: endPID.map(Int.init)
            )
        }
    }
    
    @discardableResult
    func appendResponse(
        header: String,
        mode: String,
        pid: String,
        request: String,
        response: String
    ) -> Bool {
        let parsed = ELMResponseParser.parse(response)

        guard parsed.type == .mode01 ||
              parsed.type == .mode21 ||
              parsed.type == .mode22 else {
            return false
        }

        guard !response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        let key = "\(header)|\(request)|\(response)"

        guard !seen.contains(key) else {
            return false
        }

        seen.insert(key)

        results.append(
            ScanResult(
                header: header,
                mode: mode,
                pid: pid,
                request: request,
                response: response
            )
        )
        results.sort { ($0.header, $0.request) < ($1.header, $1.request) }

        scanStatus.successCount += 1
        Logger.shared.success("✅ Found PID \(request) -> \(response)")
        saveResults()
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
