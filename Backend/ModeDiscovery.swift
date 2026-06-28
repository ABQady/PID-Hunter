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

        defer {
            isRunning = false
        }

        Logger.shared.info("🔎 Starting mode discovery")

        for mode in OBDMode.supportedScanModes {

            Logger.shared.info("🔎 Probing \(mode.title)...")

            do {
                let response = try await elm.request(mode: mode)
                if response.type.requestMode == mode.requestService {
                    handleSuccess(mode)
                } else {
                    handleFailure(mode)
                }
            } catch {
                handleFailure(mode)
            }
        }
        Logger.shared.success("🏁 Mode discovery finished")
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

