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
    @Published private(set) var hasResumePoint = false
    
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
    
    private func saveResumePoint(force: Bool = false) {
        if !force && (currentPID % 10 != 0) {
            return
        }

        let defaults = UserDefaults.standard
        defaults.set(currentHeaderIndex, forKey: "resumeHeader")
        defaults.set(currentPID, forKey: "resumePID")

        let stats = ScanStatistics.shared
        defaults.set(stats.requestsSent, forKey: "resumeRequestsSent")
        defaults.set(stats.responses, forKey: "resumeResponses")
        defaults.set(stats.positiveResponses, forKey: "resumePositiveResponses")
        defaults.set(stats.negativeResponses, forKey: "resumeNegativeResponses")
        defaults.set(stats.timeouts, forKey: "resumeTimeouts")
        defaults.set(stats.startedAt, forKey: "resumeStartedAt")

        refreshResumeAvailability()
    }
    
    private func beginScan() {
        shouldStop = false
        scanStatus.isScanning = true
        scanStatus.progress = 0
        scanStatus.currentRequest = ""
    }
    
    private func finishScan(completed: Bool) {
        scanStatus.isScanning = false
        scanStatus.currentRequest = ""

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
        stats.requestsSent = defaults.object(forKey: "resumeRequestsSent") as? Int ?? 0
        stats.responses = defaults.object(forKey: "resumeResponses") as? Int ?? 0
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
        scanStatus.progress = ScanStatistics.shared.totalRequests > 0
            ? Double(ScanStatistics.shared.requestsSent) / Double(ScanStatistics.shared.totalRequests)
            : 0
    }
    func startFresh() {

        shouldStop = false
        scanStatus.progress = 0
        scanStatus.currentRequest = ""
        scanStatus.isScanning = false
        
        currentHeaderIndex = 0
        currentPID = 0

        results.removeAll()
        seen.removeAll()
        scanStatus.successCount = 0

        UserDefaults.standard.removeObject(forKey: "savedResults")
        Logger.shared.clear()
        ScanStatistics.shared.reset()
        
        clearResumePoint()
    }
    
    func clearResumePoint() {
        currentHeaderIndex = 0
        currentPID = 0
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
    
    var headers = [
        "81F111",
        "80F111",
        "82F111"
    ]
    

    func stop() {
        shouldStop = true
        ScanStatistics.shared.finish()
    }
    
    // MARK: - Generic Scan Implementation
    private func scan(
        mode: OBDMode,
        startPID: Int? = nil,
        endPID: Int? = nil
    ) async {
        let pidWidth = mode.pidDigits
        let startPID = startPID ?? mode.defaultStartPID
        let endPID = endPID ?? mode.defaultEndPID
        
        loadResumePoint()
        if currentHeaderIndex >= headers.count {
            currentHeaderIndex = 0
        }
        // Clamp currentPID to range
        if currentPID < startPID || currentPID > endPID {
            currentPID = startPID
        }

        // Clear or load results as needed
        if currentHeaderIndex == 0 && currentPID == startPID {
            clearResults()
        } else {
            loadResults()
        }

        let count = endPID - startPID + 1
        let total = headers.count * count
        var done = currentHeaderIndex * count + (currentPID - startPID)

        let stats = ScanStatistics.shared

        if currentHeaderIndex == 0 && currentPID == startPID {
            stats.reset()
            stats.totalRequests = total
            stats.start()
        } else {
            stats.totalRequests = total
            if stats.startedAt == nil {
                stats.start()
            }
        }

        beginScan()
        var consecutiveTimeouts = 0

        while currentHeaderIndex < headers.count {
            let header = headers[currentHeaderIndex]
            ELM327.shared.setHeader(header)
            try? await Task.sleep(for: .milliseconds(50))
            while currentPID <= endPID {
                if shouldStop {
                    finishScan(completed: false)
                    return
                }

                let pid = String(format: "%0*X", pidWidth, currentPID)
                let req = mode.rawValue + pid
                scanStatus.currentRequest = req
                if !BluetoothManager.shared.isConnected {
                    guard await ensureConnection(header: header) else {
                        continue
                    }
                    continue
                }
                do {
                    let response = try await BluetoothManager.shared.sendAndWait(
                        req,
                        timeout: .seconds(requestTimeout)
                    )
                    stats.requestsSent += 1
                    stats.responses += 1

                    let parsed = ELMResponseParser.parse(response.raw)
                    switch parsed.type {
                    case .mode01, .mode21, .mode22:
                        stats.positiveResponses += 1
                    case .negative:
                        stats.negativeResponses += 1
                    default:
                        break
                    }
                    resetTimeoutCounter(&consecutiveTimeouts)
                    appendResponse(
                        header: header,
                        mode: mode.rawValue,
                        pid: String(req.dropFirst(2)),
                        request: req,
                        response: response.raw
                    )
                    if delayMs > 0 {
                        try? await Task.sleep(for: .milliseconds(Int(delayMs)))
                    }
                } catch BluetoothManager.BluetoothError.timeout {
                    stats.requestsSent += 1
                    stats.timeouts += 1
                    stats.responses += 1

                    consecutiveTimeouts += 1

                    if consecutiveTimeouts >= maxConsecutiveTimeouts {
                        Logger.shared.error("Consecutive timeout limit (\(maxConsecutiveTimeouts)) reached. Stopping scan.")
                        ScanStatistics.shared.finish()
                        finishScan(completed: false)
                        return
                    }
                    await handleTimeout()
                } catch {
                    if !BluetoothManager.shared.isConnected {
                        guard await handleConnectionLoss(header: header, consecutiveTimeouts: &consecutiveTimeouts) else {
                            continue
                        }
                        continue
                    }
                }
                done += 1
                currentPID += 1
                saveResumePoint()
                scanStatus.progress = Double(done) / Double(total)
            }
            currentHeaderIndex += 1
            currentPID = startPID
            saveResumePoint()
        }
        ScanStatistics.shared.finish()
        finishScan(completed: true)
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
    
    func appendResponse(
        header: String,
        mode: String,
        pid: String,
        request: String,
        response: String
    ) {
        let parsed = ELMResponseParser.parse(response)

        guard parsed.type == .mode01 ||
              parsed.type == .mode21 ||
              parsed.type == .mode22 else {
            return
        }

        guard !response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let key = "\(header)|\(request)|\(response)"

        guard !seen.contains(key) else {
            return
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
