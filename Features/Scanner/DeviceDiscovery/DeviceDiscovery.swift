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

        Logger.shared.success(
            "🏁 Device discovery finished (\(discoverySession.respondingAddresses.count) devices)"
        )

        for record in discoverySession.successfulRecords {

            Logger.shared.info(
                String(
                    format: "Requested=%02X  Responded=%02X",
                    record.requestAddress,
                    record.respondingAddress
                )
            )
        }
        
        if !discoverySession.successfulRecords.isEmpty {

            BikeProfileManager.shared.updateDeviceDiscoveries(discoverySession.successfulRecords)

            Logger.shared.info(
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

        defer {
            isRunning = false
        }

        Logger.shared.info("────────────")
        Logger.shared.info("🔎 Starting device discovery")

        Logger.shared.info("🔧 Initializing ELM for discovery session...")
        await elm.initializeELM()

        for address in UInt8.min...UInt8.max {
            await probe(address)
            try? await Task.sleep(for: .milliseconds(20))
        }

        finishDiscovery()

        return discoveredDevices
    }
    

    private func probe(_ address: UInt8) async {

        Logger.shared.info(
            String(format: "🔎 Probing %02X...", address)
        )

        do {

            let command = discoveryCommand(for: address)

            Logger.shared.verbose("📤 \(command)")

            let result = try await elm.request(command: command)

            let response = result.response
            let latency = result.latency

            let decision = interpreter.interpret(
                requestAddress: address,
                response: response
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

                discoveryLog.append(
                    DiscoveryResult(
                        requestedAddress: address,
                        respondingAddress: response.respondingAddress,
                        response: response,
                        latency: latency,
                        success: false
                    )
                )

                handleFailure(address)
            }

        } catch BluetoothManager.BluetoothError.timeout {

            Logger.shared.warning(
                String(format: "⏰ %02X Timeout", address)
            )

            handleFailure(address)

        } catch {

            Logger.shared.error(
                String(
                    format: "❌ %02X %@", address, error.localizedDescription
                )
            )

            handleFailure(address)
        }
    }

    private func discoveryCommand(for address: UInt8) -> String {

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
            String(format: "❌ %02X Unsupported", address)
        )
    }

    func reset() async {

        discoveryLog.removeAll(keepingCapacity: true)
        discoverySession.records.removeAll(keepingCapacity: true)
        
    }
}
