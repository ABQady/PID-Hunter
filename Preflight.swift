//
//  Preflight.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 26/06/2026.
//
import Foundation

@MainActor
final class Preflight {

    static let shared = Preflight()

    func run(header: String) async -> Bool {

        Logger.shared.info("========== PREFLIGHT ==========")

        guard BluetoothManager.shared.isConnected else {
            Logger.shared.info("❌ Bluetooth: Not Connected")
            return false
        }

        guard BluetoothManager.shared.writeCharacteristic != nil else {
            Logger.shared.info("❌ TX Characteristic Missing")
            return false
        }

        guard BluetoothManager.shared.notifyCharacteristic != nil else {
            Logger.shared.info("❌ RX Characteristic Missing")
            return false
        }

        Logger.shared.info("✅ Bluetooth Connected")
        Logger.shared.info("✅ TX Found")
        Logger.shared.info("✅ RX Found")

        ELM327.shared.send("ATDP")
        try? await Task.sleep(for: .milliseconds(500))

        ELM327.shared.setHeader(header)
        try? await Task.sleep(for: .milliseconds(300))

        ELM327.shared.send("0100")
        try? await Task.sleep(for: .seconds(2))

        let rx = BluetoothManager.shared.lastResponse.uppercased()

        if rx.contains("41") {
            Logger.shared.info("✅ ECU Responded")
            return true
        }

        if rx.contains("NO DATA") {
            Logger.shared.info("⚠️ ECU Reachable but returned NO DATA")
            return true
        }

        Logger.shared.info("❌ ECU did not respond")
        return false
    }
}
