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
        Logger.shared.info(
            "Supported Modes: " +
            supportedModes
                .map(\.rawValue)
                .joined(separator: ", ")
        )
    }

    private func probe(_ mode: OBDMode) async {
        Logger.shared.info("🔎 Probing \(mode.title)...")

        do {
            let result = try await elm.request(command: mode.discoveryCommand)
            let response = result.response
            let latency = result.latency

            let requestMode = mode.requestService

            Logger.shared.debug(
                """
                Mode Discovery
                  Request : \(String(format: "%02X", requestMode))
                  Response: \(response.service.map { String(format: "%02X", $0) } ?? "--")
                  Type    : \(response.type)
                  Raw     : \(response.raw)
                """
            )
            
            let supported = isSupportedResponse(response, for: mode)

            discoveryLog.append(
                DiscoveryResult(
                    mode: mode,
                    response: response,
                    latency: latency,
                    success: supported
                )
            )
            if supported {
                if case .negative = response.type {
                    Logger.shared.warning(
                        "⚠️ \(mode.title) Negative Response (Supported)"
                    )
                }
                handleSuccess(mode)
            } else {
                Logger.shared.warning(
                    """
                    ❌ \(mode.title) Unsupported
                    Request Service : \(String(format: "%02X", requestMode))
                    Parsed Service  : \(response.service.map { String(format: "%02X", $0) } ?? "--")
                    Parsed Type     : \(response.type)
                    """
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

    private func isSupportedResponse(
        _ response: ELMResponse,
        for mode: OBDMode
    ) -> Bool {

        // Positive response parsed by the parser.
        if case .negative = response.type {
            // fall through to negative-response handling
        } else if let service = response.service,
                  service == mode.requestService {
            return true
        }

        // Negative response proving the ECU understood the request.
        guard case .negative = response.type,
              let service = response.service else {
            return false
        }

        return service == mode.requestService
    }

    private init() { }

    func discover(on header: String? = nil) async -> [OBDMode] {

        supportedModes.removeAll()
        discoveryLog.removeAll()
        
        guard !isRunning else {
            return supportedModes
        }

        isRunning = true

        Logger.shared.info("────────────")

        defer {
            isRunning = false
        }

        Logger.shared.info("🔎 Starting mode discovery")

        if let header {
            Logger.shared.info("Using header: \(header)")
            elm.send("ATSH\(header)")
        }

        for mode in OBDMode.discoveryModes {
            await probe(mode)
        }
        finishDiscovery()
        return supportedModes
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
        discoveryLog.removeAll(keepingCapacity: true)
    }
}
