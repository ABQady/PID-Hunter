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

    struct ELMRequestResult {
        let response: ELMResponse
        let latency: TimeInterval
    }
    
    private init() {}
    
    @inline(__always)
    private func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    
    // MARK: - Send
    func send(_ command: String) {
        let normalized = normalize(command)

        guard !normalized.isEmpty else { return }

        do {
            try BluetoothManager.shared.send(normalized)
        } catch {
            Logger.shared.error("ELM327.send failed: \(normalized)")
        }
    }

    // MARK: - Header
    func setHeader(_ header: String) {
        let normalized = normalize(header)

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
    ) async throws -> ELMRequestResult {

        let result = try await BluetoothManager.shared.sendAndWait(
            makeCommand(mode: mode, pid: pid),
            timeout: timeout
        )

        return ELMRequestResult(
            response: result.response,
            latency: result.latency
        )
    }
    
    func request(
        mode: OBDMode,
        timeout: Duration = .seconds(1)
    ) async throws -> ELMRequestResult {

        try await request(
            mode: mode,
            pid: UInt16(mode.defaultStartPID),
            timeout: timeout
        )
    }

    func request(
        command: String,
        timeout: Duration = .seconds(1)
    ) async throws -> ELMRequestResult {

        let normalized = normalize(command)

        let result = try await BluetoothManager.shared.sendAndWait(
            normalized,
            timeout: timeout
        )

        return ELMRequestResult(
            response: result.response,
            latency: result.latency
        )
    }
    
    @inline(__always)
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
            let identificationCommands: [String] = [
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
            for command in identificationCommands {
                guard BluetoothManager.shared.isConnected else {
                    Logger.shared.warning("ECU identification aborted: disconnected")
                    return
                }

                send(command)
                try? await Task.sleep(for: .milliseconds(1000))
            }
        }
    }
}
