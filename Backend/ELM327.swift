//
//  ELM327.swift
//  PIDHunter by Ahmed AlQady
//
import Foundation
@MainActor
final class ELM327: ObservableObject {
    static let shared = ELM327()
    private(set) var currentHeader = ""
    private var pendingContinuation: CheckedContinuation<String, Error>?

    enum ELMError: Error {
        case timeout
        case busy
    }
    
    private init() {}

    
    // MARK: - Send
    func send(_ command: String) {
        do { try BluetoothManager.shared.send(command)} catch {
            return
        }
    }
    
    func completePending(with response: String) {
        pendingContinuation?.resume(returning: response)
        pendingContinuation = nil
    }

    // MARK: - Header
    func setHeader(_ header: String) {
        guard !header.isEmpty else { return }
        guard currentHeader != header else {
            return
        }
        currentHeader = header
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
