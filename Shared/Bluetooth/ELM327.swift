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
    
    @discardableResult
    func initializeELM(
    ) async -> Bool{
        do {
            currentHeader = ""
            _ = try await BluetoothManager.shared.sendAndWait(
                "ATZ",
                timeout: .seconds(2)
            )
            // Give the adapter a brief moment to reboot after ATZ.
            try? await Task.sleep(for: .milliseconds(500))

            _ = try await BluetoothManager.shared.sendAndWait("ATE0", timeout: .seconds(1))
            _ = try await BluetoothManager.shared.sendAndWait("ATL0", timeout: .seconds(1))
            _ = try await BluetoothManager.shared.sendAndWait("ATS0", timeout: .seconds(1))
            _ = try await BluetoothManager.shared.sendAndWait("ATH1", timeout: .seconds(1))
            _ = try await BluetoothManager.shared.sendAndWait("ATSP5", timeout: .seconds(2))
            _ = try await BluetoothManager.shared.sendAndWait("ATDP", timeout: .seconds(2))
            return true
        } catch {
            Logger.shared.error("❌ Failed to initialize ELM: \(error.localizedDescription)")
            return false
        }
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
    @discardableResult
    func setHeader(
        _ header: String,
        timeout: Duration = .seconds(1)
    ) async throws -> ELMRequestResult {

        let normalized = normalize(header)

        guard !normalized.isEmpty else {
            throw ELMError.timeout
        }

        if currentHeader == normalized {
            Logger.shared.verbose("Header already active -> \(normalized)")
            return ELMRequestResult(
                response: ELMResponse(
                    raw: "OK",
                    type: .atResponse,
                    header: normalized,
                    pid: nil,
                    payload: []
                ),
                latency: 0
            )
        }

        Logger.shared.debug("TX(wait) -> ATSH\(normalized)")

        let result = try await BluetoothManager.shared.sendAndWait(
            "ATSH\(normalized)",
            timeout: timeout
        )
        Logger.shared.verbose("RX(wait) <- \(result.response.raw)")
        Logger.shared.verbose(
            String(format: "Header switch completed in %.1f ms", result.latency * 1000)
        )

        currentHeader = normalized
        Logger.shared.info("Header -> \(normalized)")

        return ELMRequestResult(
            response: result.response,
            latency: result.latency
        )
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
            let identificationCommands: [(command: String, description: String)] = [
                ("ATI",   "ELM Version"),
                ("AT@1",  "Device Description"),
                ("AT@2",  "Device Identifier"),
                ("ATDP",  "Protocol"),
                ("ATDPN", "Protocol Number"),
                ("0902",  "VIN"),
                ("0904",  "Calibration ID"),
                ("0906",  "CVN"),
                ("090A",  "ECU Name")
            ]
            for item in identificationCommands {
                guard BluetoothManager.shared.isConnected else {
                    Logger.shared.warning("ECU identification aborted: disconnected")
                    return
                }
                
                Logger.shared.info("🔎 Reading \(item.description)...")
                
                do {
                    let result = try await request(
                        command: item.command,
                        timeout: .seconds(2)
                    )
                    
                    Logger.shared.verbose(
                        "ECU ID → \(item.command) = \(result.response.raw)"
                    )
                    
                    switch item.command {
                        
                    case "ATI":
                        ECUInfo.shared.elmVersion = result.response.raw
                            .replacingOccurrences(of: "ATI", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        
                    case "ATDP":
                        ECUInfo.shared.protocolName = result.response.raw
                            .replacingOccurrences(of: "ATDP", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        
                    case "AT@1":
                        ECUInfo.shared.ecuName = result.response.raw
                            .replacingOccurrences(of: "AT@1", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        
                    case "AT@2":
                        ECUInfo.shared.ecuIdentifier = result.response.raw
                            .replacingOccurrences(of: "AT@2", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        
                    case "0902":
                        if case .positive = result.response.type {
                            ECUInfo.shared.ecuIdentifier = result.response.raw
                        }
                        
                    case "0904":
                        if case .positive = result.response.type {
                            ECUInfo.shared.calibrationIdentifier = result.response.raw
                        }
                        
                    case "090A":
                        if case .positive = result.response.type {
                            ECUInfo.shared.ecuName = result.response.raw
                        }
                        
                    default:
                        break
                    }
                    
                    Logger.shared.info(
                        "📘 Fingerprint → Header=\(ECUInfo.shared.header) | Protocol=\(ECUInfo.shared.protocolName)"
                    )
                } catch {
                    Logger.shared.verbose(
                        "ECU ID → \(item.command) failed"
                    )
                }
                
                try? await Task.sleep(for: .milliseconds(300))
            }
        }
        let fingerprint = ECUInfo.shared.fingerprint

        if BikeProfileManager.shared.load(for: fingerprint) != nil {
            Logger.shared.info("✅ Bike Profile refreshed from ECU identification.")
        } else {
            Logger.shared.warning("⚠️ Failed to refresh Bike Profile after ECU identification.")
        }
    }
}
