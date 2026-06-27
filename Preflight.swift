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
            Logger.shared.error("❌ Bluetooth: Not Connected")
            return false
        }

        guard BluetoothManager.shared.writeCharacteristic != nil else {
            Logger.shared.error("❌ TX Characteristic Missing")
            return false
        }

        guard BluetoothManager.shared.notifyCharacteristic != nil else {
            Logger.shared.error("❌ RX Characteristic Missing")
            return false
        }

        Logger.shared.success("✅ Bluetooth Connected")
        Logger.shared.success("✅ TX Found")
        Logger.shared.success("✅ RX Found")

        ELM327.shared.send("ATDP")
        try? await Task.sleep(for: .milliseconds(500))

        ELM327.shared.setHeader(header)
        try? await Task.sleep(for: .milliseconds(300))

        ELM327.shared.send("0100")
        try? await Task.sleep(for: .seconds(2))

        let rx = BluetoothManager.shared.lastResponse.uppercased()

        if rx.contains("41") {
            Logger.shared.success("✅ ECU Responded")
            return true
        }

        if rx.contains("NO DATA") {
            Logger.shared.warning("⚠️ ECU Reachable but returned NO DATA")
            return true
        }

        Logger.shared.error("❌ ECU did not respond")
        return false
    }
}
