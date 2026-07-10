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
            Logger.shared.debug("TX -> \(normalized)")
            try BluetoothManager.shared.send(normalized)
        } catch {
            Logger.shared.error("ELM327.send failed: \(normalized) | \(error.localizedDescription)")
        }
    }

    // MARK: - Header
    func setHeader(_ header: String) {
        let normalized = normalize(header)

        guard !normalized.isEmpty else { return }
        guard currentHeader != normalized else { return }

        do {
            Logger.shared.debug("TX -> ATSH\(normalized)")
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

        guard let firstPID = mode.pidRange?.lowerBound else {
            return try await request(
                command: mode.runtimeRequests.first ?? mode.rawValue,
                timeout: timeout
            )
        }

        return try await request(
            mode: mode,
            pid: UInt16(firstPID),
            timeout: timeout
        )
    }

    func request(
        command: String,
        timeout: Duration = .seconds(1)
    ) async throws -> ELMRequestResult {

        let normalized = normalize(command)

        Logger.shared.debug("TX(wait) -> \(normalized)")
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
        let width = mode.scanCapability.pidWidth
        if width > 0 {
            return mode.rawValue + String(format: "%0\(width)X", pid)
        }
        return mode.rawValue
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
