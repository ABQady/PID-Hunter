//
//  ELM327.swift
//  PIDHunter by Ahmed AlQady
//
import Foundation
@MainActor
final class ELM327: ObservableObject {
    static let shared = ELM327()
    private(set) var currentHeader = ""

    enum ELMError: Error {
        case timeout
        case busy
    }
    
    private init() {}

    
    // MARK: - Send
    func send(_ command: String) {
        let normalized = command
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard !normalized.isEmpty else { return }

        do {
            try BluetoothManager.shared.send(normalized)
        } catch {
            Logger.shared.error("ELM327.send failed: \(normalized)")
        }
    }

    // MARK: - Header
    func setHeader(_ header: String) {
        let normalized = header.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        guard !normalized.isEmpty else { return }
        guard currentHeader != normalized else { return }

        do {
            try BluetoothManager.shared.send("ATSH\(normalized)")
            currentHeader = normalized
            Logger.shared.info("Header -> \(normalized)")
        } catch {
            Logger.shared.error("Failed to set header: \(normalized)")
        }
    }
    // MARK: - PID Requests
    func request(
        mode: OBDMode,
        pid: UInt16
    ) {
        send(makeCommand(mode: mode, pid: pid))
    }

    func request(
        mode: OBDMode,
        pid: UInt16,
        timeout: Duration = .seconds(1)
    ) async throws -> ELMResponse {

        let result = try await BluetoothManager.shared.sendAndWait(
            makeCommand(mode: mode, pid: pid),
            timeout: timeout
        )

        return result.response
    }
    
    func request(
        mode: OBDMode,
        timeout: Duration = .seconds(1)
    ) async throws -> ELMResponse {

        try await request(
            mode: mode,
            pid: UInt16(mode.defaultStartPID),
            timeout: timeout
        )
    }
    
    private func makeCommand(
        mode: OBDMode,
        pid: UInt16
    ) -> String {

        mode.rawValue +
        String(
            format: "%0\(mode.pidDigits)X",
            pid
        )
    }

    // MARK: - ECU Identification
    func identifyECU() {
        Task {
            let commands: [String] = [
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
                guard BluetoothManager.shared.isConnected else {
                    Logger.shared.warning("ECU identification aborted: disconnected")
                    return
                }
                send(cmd)
                try? await Task.sleep(
                    for: .milliseconds(1000)
                )
            }
        }
    }
}
