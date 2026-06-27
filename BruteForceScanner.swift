//
//  BruteForceScanner.swift
//  PIDHunter by Ahmed AlQady
//
import Foundation
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
    
    private var shouldStop = false
    private var seen = Set<String>()
    private let requestTimeout: TimeInterval = 2.0
    
    private var currentHeaderIndex = 0
    private var currentPID = 0
    
    private func saveResumePoint() {
        UserDefaults.standard.set(currentHeaderIndex, forKey: "resumeHeader")
        UserDefaults.standard.set(currentPID, forKey: "resumePID")
    }
    
    private func beginScan() {
        shouldStop = false
        scanStatus.isScanning = true
        scanStatus.progress = 0
        scanStatus.currentRequest = ""
        RequestResponseMatcher.shared.clear()
    }
    
    private func finishScan(completed: Bool) {
        scanStatus.isScanning = false
        scanStatus.currentRequest = ""

        if completed {
            scanStatus.progress = 1.0
            clearResumePoint()
        } else {
            saveResumePoint()
            saveResults()
        }

        RequestResponseMatcher.shared.clear()
        shouldStop = false
    }

    private func loadResumePoint() {
        currentHeaderIndex = UserDefaults.standard.integer(forKey: "resumeHeader")
        currentPID = UserDefaults.standard.integer(forKey: "resumePID")
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
        RequestResponseMatcher.shared.clear()
        ScanStatistics.shared.reset()
        
        saveResumePoint()
    }
    
    func clearResumePoint() {
        currentHeaderIndex = 0
        currentPID = 0
        saveResumePoint()
    }
    
    var hasResumePoint: Bool {
        let header = UserDefaults.standard.integer(forKey: "resumeHeader")
        let pid = UserDefaults.standard.integer(forKey: "resumePID")

        return header != 0 || pid != 0
    }
    
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
        
        let ok = await Preflight.shared.run(header: header)

        guard ok else {
            Logger.shared.error("❌ Reconnect failed")
            return false
        }

        ELM327.shared.setHeader(header)
        try? await Task.sleep(for: .milliseconds(100))
        
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
    
    // MARK: SCAN MODE 01
    
    func scanMode01() {
        Task {
            ScanStatistics.shared.reset()
            loadResumePoint()
            if currentHeaderIndex >= headers.count {
                currentHeaderIndex = 0
                currentPID = 0
            }
//            ELM327.shared.send("ATPC")
//            try? await Task.sleep(for: .milliseconds(200))
            
            if currentHeaderIndex == 0 && currentPID == 0 {
                clearResults()
            } else {
                loadResults()
            }
            
            let total =
            headers.count * 256
            
            ScanStatistics.shared.reset()
            ScanStatistics.shared.totalRequests = total
            
            beginScan()
            
            var done =
                currentHeaderIndex * 256 +
                currentPID
            while currentHeaderIndex < headers.count {

                let header = headers[currentHeaderIndex]

                ELM327.shared.setHeader(header)

                while currentPID <= 0x00FF {
                    if shouldStop {
                        finishScan(completed: false)
                        return
                    }

                    let req = String(format: "01%02X", UInt8(currentPID))
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
                            timeout: .seconds(2)
                        )
                        appendResponse(
                            header: header,
                            mode: String(req.prefix(2)),
                            pid: String(req.dropFirst(2)),
                            request: req,
                            response: response.raw
                        )
                        if delayMs > 0 {
                            try? await Task.sleep(for: .milliseconds(Int(delayMs)))
                        }
                    } catch BluetoothManager.BluetoothError.timeout {
                        Logger.shared.warning("⏰ Request timeout")
                        if delayMs > 0 {
                            try? await Task.sleep(for: .milliseconds(Int(delayMs)))
                        }
                    } catch {
                        if !BluetoothManager.shared.isConnected {
                            Logger.shared.error("Connection lost")
                            guard await ensureConnection(header: header) else {
                                continue
                            }
                            continue
                        }
                    }
                    done += 1
                    currentPID += 1
                    saveResumePoint()
                    scanStatus.progress =
                    Double(done)
                    /
                    Double(total)
                    //try? await Task.sleep(
                    //    nanoseconds: delay
                    //)
                }
                currentHeaderIndex += 1
                currentPID = 0
                saveResumePoint()
            }
            ScanStatistics.shared.finish()
            finishScan(completed: true)
        }
    }
    
    // MARK: SCAN MODE 21

    func scanMode21() {
        Task {
            loadResumePoint()
            if currentHeaderIndex >= headers.count {
                currentHeaderIndex = 0
                currentPID = 0
            }
//            ELM327.shared.send("ATPC")
//            try? await Task.sleep(for: .milliseconds(200))
            if currentHeaderIndex == 0 && currentPID == 0 {
                clearResults()
            } else {
                loadResults()
            }
            let total =
            headers.count * 256
            
            ScanStatistics.shared.reset()
            ScanStatistics.shared.totalRequests = total
            
            beginScan()
            
            var done =
                currentHeaderIndex * 256 +
                currentPID
            while currentHeaderIndex < headers.count {

                let header = headers[currentHeaderIndex]

                ELM327.shared.setHeader(header)

                while currentPID <= 0x00FF {

                    if shouldStop {
                        finishScan(completed: false)
                        return
                    }

                    let req = String(format: "21%02X", UInt8(currentPID))
                    
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
                            timeout: .seconds(2)
                        )
                        appendResponse(
                            header: header,
                            mode: String(req.prefix(2)),
                            pid: String(req.dropFirst(2)),
                            request: req,
                            response: response.raw
                        )
                        if delayMs > 0 {
                            try? await Task.sleep(for: .milliseconds(Int(delayMs)))
                        }
                    } catch BluetoothManager.BluetoothError.timeout {
                        Logger.shared.warning("⏰ Request timeout")
                        if delayMs > 0 {
                            try? await Task.sleep(for: .milliseconds(Int(delayMs)))
                        }
                    } catch {
                        if !BluetoothManager.shared.isConnected {
                            Logger.shared.error("Connection lost")
                            guard await ensureConnection(header: header) else {
                                continue
                            }
                            continue
                        }
                    }
                    done += 1
                    currentPID += 1
                    saveResumePoint()
                    scanStatus.progress =
                    Double(done)
                    /
                    Double(total)
                }
                currentHeaderIndex += 1
                currentPID = 0
                saveResumePoint()
            }
            ScanStatistics.shared.finish()
            finishScan(completed: true)
        }
    }
    
    // MARK: SCAN MODE 22

    func scanMode22(
        start: UInt16 = 0x0000,
        end: UInt16 = 0xFFFF
    ) {
        Task {
            loadResumePoint()
            
            if currentHeaderIndex >= headers.count {
                currentHeaderIndex = 0
            }
            
            if currentPID < start || currentPID > end {
                currentPID = Int(start)
            }
            
//            ELM327.shared.send("ATPC")
//            try? await Task.sleep(for: .milliseconds(200))
            
            if currentHeaderIndex == 0 && currentPID == Int(start) {
                clearResults()
            } else {
                loadResults()
            }
            
            beginScan()

            let count = Int(end) - Int(start) + 1
            let total = headers.count * count
            var done =
                currentHeaderIndex * count +
                Int(currentPID - Int(start))
            
            ScanStatistics.shared.reset()
            ScanStatistics.shared.totalRequests = total
            
            while currentHeaderIndex < headers.count {
                let header = headers[currentHeaderIndex]
                ELM327.shared.setHeader(header)
                while currentPID <= Int(end) {
                    if shouldStop {
                        finishScan(completed: false)
                        return
                    }

                    let req = String(format: "22%04X", UInt16(currentPID))
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
                            timeout: .seconds(2)
                        )
                        appendResponse(
                            header: header,
                            mode: String(req.prefix(2)),
                            pid: String(req.dropFirst(2)),
                            request: req,
                            response: response.raw
                        )
                        if delayMs > 0 {
                            try? await Task.sleep(for: .milliseconds(Int(delayMs)))
                        }
                    } catch BluetoothManager.BluetoothError.timeout {
                        Logger.shared.warning("⏰ Request timeout")
                        if delayMs > 0 {
                            try? await Task.sleep(for: .milliseconds(Int(delayMs)))
                        }
                    } catch {
                        if !BluetoothManager.shared.isConnected {
                            Logger.shared.error("Connection lost")
                            guard await ensureConnection(header: header) else {
                                continue
                            }
                            continue
                        }
                    }
                    done += 1
                    currentPID += 1
                    saveResumePoint()
                    scanStatus.progress =
                    Double(done)
                    /
                    Double(total)
                }
                currentHeaderIndex += 1
                currentPID = Int(start)
                saveResumePoint()
            }
            ScanStatistics.shared.finish()
            finishScan(completed: true)
        }
    }
    func appendResponse(
        header: String,
        mode: String,
        pid: String,
        request: String,
        response: String
    ) {
        let upper =
        response.uppercased()
        if upper.contains("NO DATA")
            || upper.contains("?")
            || upper.contains("ERROR")
            || upper.contains("UNABLE TO CONNECT")
            || upper.contains("STOPPED")
            || upper.contains("BUS ERROR")
            || upper.contains("BUFFER FULL")
            || upper.contains("SEARCHING")
            || upper.contains("OK")
            || upper == ">"
        {
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

        Logger.shared.success("✅ Found PID \(request) -> \(response)")

        scanStatus.successCount += 1
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

