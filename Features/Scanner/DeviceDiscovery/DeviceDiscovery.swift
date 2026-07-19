//
//  DeviceDiscovery.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 16/07/2026.
//

import Foundation
@MainActor
final class DeviceDiscovery: ObservableObject {

    struct DiscoveryResult {
        let requestedAddress: UInt8
        let respondingAddress: UInt8?
        let response: ELMResponse?
        let latency: Double
        let success: Bool
    }

    @Published private(set) var discoveryLog: [DiscoveryResult] = []
    @Published private(set) var discoverySession = DiscoverySession()
    private let statistics = ProgressStatistics.shared

    var discoveredDevices: [DeviceDiscoveryResult] {
        discoverySession.successfulRecords.map {
            DeviceDiscoveryResult(
                requestedAddress: $0.requestAddress,
                respondingAddress: $0.respondingAddress
            )
        }
    }

    struct DeviceDiscoveryResult: Hashable {
        let requestedAddress: UInt8
        let respondingAddress: UInt8
    }

    @Published private(set) var isRunning = false

    static let shared = DeviceDiscovery()

    private let elm = ELM327.shared
    private let interpreter = KWPDiscoveryInterpreter()

    private init() { }

    @inline(__always)
    private func finishDiscovery() {

        statistics.finish()

        Logger.shared.success(
            "🏁 Device discovery finished (\(discoverySession.respondingAddresses.count) devices)"
        )

        for record in discoverySession.successfulRecords {
            Logger.shared.verbose(
                .discovery,
                String(
                    format: "Requested=%02X  Responded=%02X",
                    record.requestAddress,
                    record.respondingAddress
                )
            )
        }
        
        if !discoverySession.successfulRecords.isEmpty {
            BikeProfileManager.shared.updateDeviceDiscoveries(discoverySession.successfulRecords)
            Logger.shared.verbose(
                .persistence,
                "💾 Persisted \(discoverySession.successfulRecords.count) device discoveries."
            )
        }
    }

    func discover() async -> [DeviceDiscoveryResult] {

        guard !isRunning else {
            return discoveredDevices
        }

        await reset()

        isRunning = true

        statistics.start(total: 256)

        defer {
            isRunning = false
        }

        Logger.shared.info("────────────")
        Logger.shared.info("🔎 Starting device discovery")

        Logger.shared.verbose(.setup, "🔧 Initializing ELM for discovery session...")
        await elm.initializeELM()

        Logger.shared.info("📡 Stage 1/3: Functional StartCommunication")
        await probe(0xFE)
        try? await Task.sleep(for: .milliseconds(100))

        Logger.shared.info("📡 Stage 2/3: Physical StartCommunication")
        for address in UInt8.min...UInt8.max where address != 0xFE {
            await probe(address)
            try? await Task.sleep(for: .milliseconds(20))
        }

        if discoverySession.successfulRecords.isEmpty {
            Logger.shared.warning("⚠️ No ECU discovered via StartCommunication. Falling back to diagnostic probes.")

            Logger.shared.info("📡 Stage 3/3: Fallback Diagnostic Probes (09 02 + 01 00)")

            for address in UInt8.min...UInt8.max where address != 0xFE {
                await diagnosticProbe(address)
                try? await Task.sleep(for: .milliseconds(20))
            }
        }

        finishDiscovery()

        return discoveredDevices
    }
    

    private func probe(_ address: UInt8) async {
        Logger.shared.verbose(
            .discovery,
            String(format: "🔎 Probing %02X...", address)
        )

        do {
            let command = discoveryCommand(for: address)
            Logger.shared.verbose(.communication, "📤 \(command)")
            let result = try await elm.request(command: command)

            let response = result.response
            let latency = result.latency

            Logger.shared.verbose(
                .communication,
                "📥 \(response.raw)"
            )

            if let responder = response.respondingAddress {
                Logger.shared.verbose(
                    .discovery,
                    String(format: "📍 Response address: %02X", responder)
                )
            } else {
                Logger.shared.verbose(
                    .discovery,
                    "📍 Response address: <nil>"
                )
            }

            let decision = interpreter.interpret(
                requestAddress: address,
                response: response
            )

            Logger.shared.verbose(
                .discovery,
                "🧠 Discovery decision: \(decision)"
            )

            switch decision {

            case .ecuFound(let discovery):

                discoverySession.records.append(
                    DeviceDiscoveryRecord(
                        requestAddress: discovery.requestAddress,
                        respondingAddress: discovery.respondingAddress,
                        response: response,
                        latency: latency,
                        confidence: discovery.confidence,
                        reason: discovery.reason,
                        timestamp: Date()
                    )
                )

                discoveryLog.append(
                    DiscoveryResult(
                        requestedAddress: discovery.requestAddress,
                        respondingAddress: discovery.respondingAddress,
                        response: response,
                        latency: latency,
                        success: true
                    )
                )

                statistics.record(success: true)

                Logger.shared.success(
                    String(
                        format: "✅ %02X → %02X",
                        discovery.requestAddress,
                        discovery.respondingAddress
                    )
                )

            case .unsupportedAddress,
                 .ignored,
                 .invalidResponse,
                 .transportError:

                Logger.shared.warning(
                    String(
                        format: "❌ Probe %02X rejected (Responder=%@)",
                        address,
                        response.respondingAddress.map { String(format: "%02X", $0) } ?? "nil"
                    )
                )

                discoveryLog.append(
                    DiscoveryResult(
                        requestedAddress: address,
                        respondingAddress: response.respondingAddress,
                        response: response,
                        latency: latency,
                        success: false
                    )
                )

                statistics.record(success: false)

                handleFailure(address)
            }

        } catch BluetoothManager.BluetoothError.timeout {

            Logger.shared.warning(
                String(format: "⏰ %02X Timeout", address)
            )

            handleFailure(address)

            statistics.record(success: false)

        } catch {

            Logger.shared.error(
                String(
                    format: "❌ %02X %@", address, error.localizedDescription
                )
            )

            handleFailure(address)

            statistics.record(success: false)
        }
    }

    private func diagnosticProbe(_ address: UInt8) async {
        let probes: [(String, String)] = [
            ("Identification", buildIdentificationProbe(for: address)),
            ("Diagnostic", buildDiagnosticProbe(for: address))
        ]

        for (name, command) in probes {
            Logger.shared.info(String(format: "📡 [%@] Probing %02X", name, address))
            Logger.shared.verbose(.communication, "📤 [\(name)] \(command)")

            do {
                let result = try await elm.request(command: command)

                Logger.shared.verbose(.communication, "📥 [\(name)] \(result.response.raw)")

                let decision = interpreter.interpret(
                    requestAddress: address,
                    response: result.response
                )

                Logger.shared.verbose(.discovery, "🧠 [\(name)] \(decision)")

                if case .ecuFound = decision {
                    Logger.shared.success(String(format: "✅ [%@] ECU found at %02X", name, address))
                    await probe(address)
                    break
                } else {
                    Logger.shared.warning(String(format: "❌ [%@] No ECU at %02X", name, address))
                }
            } catch {
                Logger.shared.warning(String(format: "⚠️ [%@] Probe %02X failed: %@", name, address, error.localizedDescription))
            }
        }
    }

    private func buildIdentificationProbe(for address: UInt8) -> String {
        let bytes: [UInt8] = [
            0x80,
            address,
            0xF1,
            0x09,
            0x02
        ]

        let checksum = bytes.reduce(0) { $0 + Int($1) } & 0xFF

        return (bytes + [UInt8(checksum)])
            .map { String(format: "%02X", $0) }
            .joined(separator: " ")
    }

    private func buildDiagnosticProbe(for address: UInt8) -> String {
        let bytes: [UInt8] = [
            0x80,
            address,
            0xF1,
            0x01,
            0x00
        ]

        let checksum = bytes.reduce(0) { $0 + Int($1) } & 0xFF

        return (bytes + [UInt8(checksum)])
            .map { String(format: "%02X", $0) }
            .joined(separator: " ")
    }

    private func discoveryCommand(for address: UInt8) -> String {

        // ISO 14230 StartCommunication.
        // Address 0xFE performs functional addressing (broadcast).
        // Other addresses perform physical addressing.
        let bytes: [UInt8] = [
            0x81,
            address,
            0xF1,
            0x81
        ]

        let checksum = bytes.reduce(0) { $0 + Int($1) } & 0xFF

        return (
            bytes +
            [UInt8(checksum)]
        )
        .map {
            String(format: "%02X", $0)
        }
        .joined(separator: " ")
    }


    private func handleFailure(_ address: UInt8) {
        Logger.shared.verbose(
            .discovery,
            String(format: "❌ %02X Unsupported/Rejected", address)
        )
    }

    func reset() async {

        discoveryLog.removeAll(keepingCapacity: true)
        discoverySession.records.removeAll(keepingCapacity: true)
        
        statistics.reset()
    }
}
