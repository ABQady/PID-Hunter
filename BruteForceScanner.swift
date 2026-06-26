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
@MainActor
final class BruteForceScanner: ObservableObject {
    static let shared = BruteForceScanner()
    @Published var isScanning = false
    @Published var progress: Double = 0.0
    @Published var currentRequest = ""
    @Published private(set) var results: [ScanResult] = []
    @Published var delayMs: Double = 100
    @Published var successCount = 0
    
    private var shouldStop = false
    private var seen = Set<String>()
    private let requestTimeout: TimeInterval = 2.0
    
    private var currentHeaderIndex = 0
    private var currentPID = 0
    
    private func saveResumePoint() {
        UserDefaults.standard.set(currentHeaderIndex, forKey: "resumeHeader")
        UserDefaults.standard.set(currentPID, forKey: "resumePID")
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
        successCount = saved.count
    }
    func startFresh() {
        shouldStop = false

        currentHeaderIndex = 0
        currentPID = 0

        results.removeAll()
        seen.removeAll()
        successCount = 0

        UserDefaults.standard.removeObject(forKey: "savedResults")

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
        successCount = 0

        UserDefaults.standard.removeObject(forKey: "savedResults")
    }

    private func ensureConnection(header: String) async -> Bool {
        if BluetoothManager.shared.isConnected {
            return true
        }

        Logger.shared.info("🔄 Reconnecting...")

        await BluetoothManager.shared.reconnect()
        try? await Task.sleep(for: .milliseconds(500))
        
        let ok = await Preflight.shared.run(header: header)

        guard ok else {
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
        currentRequest = ""
        RequestResponseMatcher.shared.clear()
        isScanning = false
        saveResumePoint()
        saveResults()
    }
    func scanMode01() {
        RequestResponseMatcher.shared.clear()
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
            
            shouldStop = false
            isScanning = true
            let total =
            headers.count * 256
            var done =
                currentHeaderIndex * 256 +
                currentPID
            while currentHeaderIndex < headers.count {

                let header = headers[currentHeaderIndex]

                ELM327.shared.setHeader(header)

                try? await Task.sleep(for: .milliseconds(Int(delayMs)))

                while currentPID <= 0x00FF {
                    if shouldStop {
                        saveResumePoint()
                        saveResults()

                        isScanning = false
                        currentRequest = ""
                        return
                    }

                    let req = String(format: "01%02X", UInt8(currentPID))
                    currentRequest = req
                    if !BluetoothManager.shared.isConnected {
                        RequestResponseMatcher.shared.clear()

                        guard await ensureConnection(header: header) else {
                            continue
                        }

                        continue   // يعيد نفس الـ PID
                    }
                    ELM327.shared.send(req)
                    let startWait = Date()

                    while !RequestResponseMatcher.shared.pending.isEmpty {

                        if Date().timeIntervalSince(startWait) > requestTimeout {
                            Logger.shared.info("⏰ Request timeout")
                            RequestResponseMatcher.shared.clear()

                            if !BluetoothManager.shared.isConnected {

                                Logger.shared.info("Connection lost")

                                guard await ensureConnection(header: header) else {
                                    continue
                                }
                                continue
                            }
                            break
                        }

                        try? await Task.sleep(for: .milliseconds(10))
                    }
                    done += 1
                    currentPID += 1
                    saveResumePoint()
                    progress =
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
            progress = 1.0
            isScanning = false
            currentRequest = ""
            clearResumePoint()
        }
    }
    func scanMode21() {
        RequestResponseMatcher.shared.clear()
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
            
            shouldStop = false
            isScanning = true
            let total =
            headers.count * 256
            var done =
                currentHeaderIndex * 256 +
                currentPID
            while currentHeaderIndex < headers.count {

                let header = headers[currentHeaderIndex]

                ELM327.shared.setHeader(header)

                try? await Task.sleep(for: .milliseconds(Int(delayMs)))

                while currentPID <= 0x00FF {

                    if shouldStop {
                        saveResumePoint()
                        saveResults()

                        isScanning = false
                        currentRequest = ""
                        return
                    }

                    let req = String(format: "21%02X", UInt8(currentPID))
                    
                    currentRequest = req
                    if !BluetoothManager.shared.isConnected {
                        RequestResponseMatcher.shared.clear()

                        guard await ensureConnection(header: header) else {
                            continue
                        }

                        continue   // يعيد نفس الـ PID
                    }
                    ELM327.shared.send(req)

                    let startWait = Date()

                    while !RequestResponseMatcher.shared.pending.isEmpty {

                        if Date().timeIntervalSince(startWait) > requestTimeout {
                            Logger.shared.info("⏰ Request timeout")
                            RequestResponseMatcher.shared.clear()

                            if !BluetoothManager.shared.isConnected {

                                Logger.shared.info("Connection lost")

                                guard await ensureConnection(header: header) else {
                                    continue
                                }
                                continue  // هيعيد نفس PID
                            }

                            break
                        }

                        try? await Task.sleep(for: .milliseconds(10))
                    }
                    done += 1
                    currentPID += 1
                    saveResumePoint()
                    progress =
                    Double(done)
                    /
                    Double(total)
                }
                currentHeaderIndex += 1
                currentPID = 0
                saveResumePoint()
            }
            progress = 1.0
            isScanning = false
            currentRequest = ""
            clearResumePoint()
        }
    }
    func scanMode22(
        start: UInt16 = 0x0000,
        end: UInt16 = 0xFFFF
    ) {
        RequestResponseMatcher.shared.clear()
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
            
            shouldStop = false
            isScanning = true

            let count = Int(end) - Int(start) + 1
            let total = headers.count * count
            var done =
                currentHeaderIndex * count +
                Int(currentPID - Int(start))
            while currentHeaderIndex < headers.count {
                let header = headers[currentHeaderIndex]
                ELM327.shared.setHeader(header)
                try? await Task.sleep(for: .milliseconds(Int(delayMs)))
                while currentPID <= Int(end) {
                    if shouldStop {
                        saveResumePoint()
                        saveResults()

                        isScanning = false
                        currentRequest = ""
                        return
                    }

                    let req = String(format: "22%04X", UInt16(currentPID))
                    currentRequest = req
                    if !BluetoothManager.shared.isConnected {
                        RequestResponseMatcher.shared.clear()

                        guard await ensureConnection(header: header) else {
                            continue
                        }

                        continue   // يعيد نفس الـ PID
                    }
                    ELM327.shared.send(req)

                    let startWait = Date()

                    while !RequestResponseMatcher.shared.pending.isEmpty {

                        if Date().timeIntervalSince(startWait) > requestTimeout {

                            Logger.shared.info("⏰ Request timeout")
                            RequestResponseMatcher.shared.clear()

                            if !BluetoothManager.shared.isConnected {

                                guard await ensureConnection(header: header) else {
                                    continue    // يعيد نفس PID
                                }
                                continue
                            }
                            break
                        }
                        try? await Task.sleep(for: .milliseconds(10))
                    }
                    done += 1
                    currentPID += 1
                    saveResumePoint()
                    progress =
                    Double(done)
                    /
                    Double(total)
                }
                currentHeaderIndex += 1
                currentPID = Int(start)
                saveResumePoint()
            }
            progress = 1.0
            isScanning = false
            currentRequest = ""
            clearResumePoint()
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

        Logger.shared.rx(response)
        
        successCount += 1
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

