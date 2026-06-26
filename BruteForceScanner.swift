//
//  BruteForceScanner.swift
//  PIDHunter
//
import Foundation
struct ScanResult: Codable {
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
    
    // عدلهم براحتك
    var headers = [
        "81F111",
        "80F111",
        "82F111"
    ]

    func stop() {
        shouldStop = true
        currentRequest = ""
        RequestResponseMatcher.shared.clear()
    }
    func scanMode01() {
        RequestResponseMatcher.shared.clear()
        Task {
//            ELM327.shared.send("ATPC")
//            try? await Task.sleep(for: .milliseconds(200))
            
            results.removeAll()
            seen.removeAll()
            progress = 0
            
            shouldStop = false
            isScanning = true
            let total =
            headers.count * 256
            var done = 0
            for header in headers {
                ELM327.shared.setHeader(header)
                try? await Task.sleep(
                    for: .milliseconds(Int(delayMs))
                )
                for pid in 0...255 {
                    if shouldStop {
                        isScanning = false
                        progress = 0
                        currentRequest = ""
                        return
                    }
                    let req =
                    String(
                        format: "01%02X",
                        pid
                    )
                    currentRequest = req
                    RequestResponseMatcher.shared.enqueue(
                        command: req,
                        header: header
                    )
                    
                    Logger.shared.tx(req)
                    ELM327.shared.send(req)
                    let startWait = Date()

                    while !RequestResponseMatcher.shared.pending.isEmpty {

                        if Date().timeIntervalSince(startWait) > 2.0 {
                            Logger.shared.info("⏰ Request timeout")
                            RequestResponseMatcher.shared.clear()
                            break
                        }

                        try? await Task.sleep(for: .milliseconds(10))
                    }
                    done += 1
                    progress =
                    Double(done)
                    /
                    Double(total)
                    //try? await Task.sleep(
                    //    nanoseconds: delay
                    //)
                }
            }
            isScanning = false
            currentRequest = ""
        }
    }
    func scanMode21() {
        RequestResponseMatcher.shared.clear()
        Task {
//            ELM327.shared.send("ATPC")
//            try? await Task.sleep(for: .milliseconds(200))
            results.removeAll()
            seen.removeAll()
            progress = 0
            
            shouldStop = false
            isScanning = true
            let total =
            headers.count * 256
            var done = 0
            for header in headers {
                ELM327.shared.setHeader(header)
                try? await Task.sleep(
                    for: .milliseconds(Int(delayMs))
                )
                for pid in 0...255 {
                    if shouldStop {
                        isScanning = false
                        progress = 0
                        currentRequest = ""
                        return
                    }
                    let req =
                    String(
                        format: "21%02X",
                        pid
                    )
                    RequestResponseMatcher.shared.enqueue(
                        command: req,
                        header: header
                    )
                    currentRequest = req
                    Logger.shared.tx(req)
                    ELM327.shared.send(req)

                    while !RequestResponseMatcher.shared.pending.isEmpty {
                        try? await Task.sleep(for: .milliseconds(10))
                    }
                    done += 1
                    progress =
                    Double(done)
                    /
                    Double(total)
//                    try? await Task.sleep(
//                        nanoseconds: delay
//                    )
                }
            }
            isScanning = false
            currentRequest = ""
        }
    }
    func scanMode22(
        start: UInt16 = 0x0000,
        end: UInt16 = 0xFFFF
    ) {
        RequestResponseMatcher.shared.clear()
        Task {
//            ELM327.shared.send("ATPC")
//            try? await Task.sleep(for: .milliseconds(200))
            
            results.removeAll()
            seen.removeAll()
            progress = 0
            
            shouldStop = false
            isScanning = true
//            let total =
//            headers.count
//            *
//            Int(end - start + 1)
            let count = Int(end) - Int(start) + 1
            let total = headers.count * count
            var done = 0
            for header in headers {
                ELM327.shared.setHeader(header)
                Logger.shared.info("Header -> \(header)")
                try? await Task.sleep(
                    for: .milliseconds(Int(delayMs))
                )
                for pid in start...end {
                    if shouldStop {
                        isScanning = false
                        progress = 0
                        currentRequest = ""
                        return
                    }
                    let req =
                    String(
                        format: "22%04X",
                        pid
                    )
                    RequestResponseMatcher.shared.enqueue(
                        command: req,
                        header: header
                    )
                    currentRequest = req
                    Logger.shared.tx(req)
                    ELM327.shared.send(req)

                    while !RequestResponseMatcher.shared.pending.isEmpty {
                        try? await Task.sleep(for: .milliseconds(10))
                    }
                    done += 1
                    progress =
                    Double(done)
                    /
                    Double(total)
                }
            }
            isScanning = false
            currentRequest = ""
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
//        if results.contains(where: {
//            $0.header == header &&
//            $0.request == request &&
//            $0.response == response
//        }) {
//            return
//        }
//        results.append(
//            ScanResult(
//                header: header,
//                mode: mode,
//                pid: pid,
//                request: request,
//                response: response
//            )
//        )
        let key = "\(header)|\(request)|\(response)"

        guard !seen.contains(key) else {
            return
        }

        seen.insert(key)
        Logger.shared.rx(response)
        
        successCount += 1
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

