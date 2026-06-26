//
//  ELM327.swift
//  PIDHunter
//
import Foundation
@MainActor
final class ELM327: ObservableObject {
    static let shared = ELM327()
    @Published var traffic: [String] = []
    private let maxTrafficLines = 2000
    private var initialized = false
    private init() {}
    // MARK: - Logging
    private func appendTraffic(_ line: String) {
        traffic.append(line)
        if traffic.count > maxTrafficLines {
            traffic.removeFirst(
                traffic.count - maxTrafficLines
            )
        }
    }
    private func logTX(_ text: String) {
        appendTraffic(">> \(text)")
    }
    func received(_ response: String) {
        appendTraffic("<< \(response)")
        print("<< \(response)")
    }
    func clearTraffic() {
        traffic.removeAll()
    }
    // MARK: - Send
    func send(_ command: String) {
        logTX(command)
        BluetoothManager.shared.send(command)
    }
    // MARK: - Initialize ELM
    func initialize() {
        guard !initialized else {
            return
        }
        initialized = true
        Task {
            let commands = [
                "ATZ",
                "ATE0",
                "ATL0",
                "ATS0",
                "ATH1",
                "ATSP5"
            ]
            for cmd in commands {
                send(cmd)
                try? await Task.sleep(
                    for: .milliseconds(1000)
                )
            }
        }
    }
    func resetInitialization() {
        initialized = false
    }
    // MARK: - Header
    func setHeader(
        _ header: String
    ) {
        guard !header.isEmpty else {
            return
        }
        send("ATSH\(header)")
    }
    // MARK: - PID Requests
    func requestMode01(
        pid: UInt8
    ) {
        send(
            String(
                format: "01%02X",
                pid
            )
        )
    }
    func requestMode21(
        pid: UInt8
    ) {
        send(
            String(
                format: "21%02X",
                pid
            )
        )
    }
    func requestMode22(
        pid: UInt16
    ) {
        send(
            String(
                format: "22%04X",
                pid
            )
        )
    }
    // MARK: - ECU Identification
    func identifyECU() {
        Task {
            let commands = [
                "ATI",
                "AT@1",
                "AT@2",
                "ATDP",
                "ATDPN",
                "0902",
                "0904",
                "0906",
                "090A"
            ]
            for cmd in commands {
                send(cmd)
                try? await Task.sleep(
                    for: .milliseconds(1000)
                )
            }
        }
    }
}
