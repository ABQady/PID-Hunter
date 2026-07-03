//
//  ModeDiscovery.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 28/06/2026.
//

import Foundation

@MainActor
final class ModeDiscovery: ObservableObject {

    static let shared = ModeDiscovery()

    @Published private(set) var supportedModes: [OBDMode] = []
    @Published private(set) var isRunning = false

    private let elm = ELM327.shared

    private init() { }

    func discover() async {

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

        for mode in OBDMode.supportedScanModes {
            Logger.shared.info("🔎 Probing \(mode.title)...")
            do {
                let result = try await elm.request(mode: mode)
                let response = result.response

                if response.type.requestMode == mode.requestService {
                    handleSuccess(mode)
                } else {
                    Logger.shared.warning(
                        "Unexpected response for \(mode.rawValue): \(response.raw)"
                    )
                    handleFailure(mode)
                }
            } catch BluetoothManager.BluetoothError.timeout {
                Logger.shared.warning("⏰ \(mode.rawValue) Timeout")
                handleFailure(mode)
            } catch {
                Logger.shared.error(
                    "❌ \(mode.rawValue): \(error.localizedDescription)"
                )
                handleFailure(mode)
            }
        }
        Logger.shared.success(
            "🏁 Mode discovery finished (\(supportedModes.count) supported)"
        )
    }

    func handleSuccess(_ mode: OBDMode) {

        guard !supportedModes.contains(mode) else {
            return
        }

        supportedModes.append(mode)

        Logger.shared.success("✅ \(mode.title) Supported")
    }

    func handleFailure(_ mode: OBDMode) {
        Logger.shared.warning("❌ \(mode.title) Unsupported")
    }

    func reset() {
        supportedModes.removeAll()
    }
}

