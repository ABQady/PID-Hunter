//
//  ModeDiscovery.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 28/06/2026.
//

import Foundation

@MainActor
final class ModeDiscovery: ObservableObject {

    struct DiscoveryResult {
        let mode: OBDMode
        let response: ELMResponse?
        let latency: Double
        let success: Bool
    }
    
    @Published private(set) var discoveryLog: [DiscoveryResult] = []
    
    static let shared = ModeDiscovery()

    @Published private(set) var supportedModes: [OBDMode] = []
    @Published private(set) var isRunning = false

    private let elm = ELM327.shared

    @inline(__always)
    private func finishDiscovery() {
        Logger.shared.success(
            "🏁 Mode discovery finished (\(supportedModes.count) supported)"
        )
    }

    private func probe(_ mode: OBDMode) async {
        Logger.shared.info("🔎 Probing \(mode.title)...")

        do {
            let result = try await elm.request(command: mode.discoveryCommand)
            let response = result.response
            let latency = result.latency

            let requestMode = mode.requestService
            let responseMode = response.type.requestMode
            Logger.shared.debug(
                """
                Mode Discovery
                  Request : \(String(format: "%02X", requestMode))
                  Response: \(responseMode.map { String(format: "%02X", $0) } ?? "--")
                  Type    : \(response.type)
                  Raw     : \(response.raw)
                """
            )
            discoveryLog.append(
                DiscoveryResult(
                    mode: mode,
                    response: response,
                    latency: latency,
                    success: response.type == .negative ||
                             response.type.requestMode == mode.requestService
                )
            )
            
            if response.type == .negative {

                Logger.shared.warning(
                    "⚠️ \(mode.title) Negative Response (Supported)"
                )

                handleSuccess(mode)
                return
            }

            if responseMode == requestMode {
                handleSuccess(mode)
            } else {
                Logger.shared.warning(
                    "Unexpected response for \(mode.title)"
                )
                handleFailure(mode)
            }
        } catch BluetoothManager.BluetoothError.timeout {
            Logger.shared.warning("⏰ \(mode.rawValue) Timeout")
            handleFailure(mode)
        } catch {
            Logger.shared.error("❌ \(mode.rawValue): \(error.localizedDescription)")
            handleFailure(mode)
        }
    }

    private init() { }

    func discover() async {

        supportedModes.removeAll()
        discoveryLog.removeAll()
        
        guard !isRunning else {
            return
        }

        isRunning = true
        supportedModes.removeAll()
        Logger.shared.info("────────────")

        defer {
            isRunning = false
        }

        Logger.shared.info("🔎 Starting mode discovery")

        for mode in OBDMode.discoveryModes {
            await probe(mode)
        }
        finishDiscovery()
    }

    func handleSuccess(_ mode: OBDMode) {

        guard !supportedModes.contains(mode) else {
            return
        }

        supportedModes.append(mode)
        // هيتسجل من probe() لما نقرر نخزن الـ response

        Logger.shared.success("✅ \(mode.title) Supported")
    }

    func handleFailure(_ mode: OBDMode) {
        Logger.shared.warning("❌ \(mode.title) Unsupported")
    }

    func reset() {
        supportedModes.removeAll(keepingCapacity: true)
    }
}
