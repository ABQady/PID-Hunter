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

        let normalizedHeader = header
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard normalizedHeader.count == 6,
              normalizedHeader.allSatisfy(\.isHexDigit) else {
            Logger.shared.error("❌ Invalid Header")
            return false
        }

        do {
            let protocolResult =
            try await BluetoothManager.shared.sendAndWait(
                "ATDP",
                timeout: .seconds(2)
            )
            let protocolResponse = protocolResult.response

            Logger.shared.info(
                "Protocol: \(protocolResponse.raw)"
            )
            let protocolText = protocolResponse.raw.uppercased()

            if protocolText.contains("?") {
                Logger.shared.warning("⚠️ Unable to identify protocol")
            } else {
                Logger.shared.info("Protocol: \(protocolResponse.raw)")
            }
        } catch BluetoothManager.BluetoothError.timeout {
            Logger.shared.error("❌ ELM327 Timeout")
            return false
        }
        catch {
            Logger.shared.error("❌ Failed to communicate with ELM327")
            return false
        }

        guard BluetoothManager.shared.isConnected else {
            Logger.shared.error("❌ Bluetooth Disconnected")
            return false
        }

        do {
            _ = try await BluetoothManager.shared.sendAndWait(
                "ATSH \(normalizedHeader)",
                timeout: .seconds(1)
            )
            Logger.shared.info(
                "Header: \(normalizedHeader)"
            )
        } catch BluetoothManager.BluetoothError.timeout {
            Logger.shared.error("❌ Header Timeout")
            return false
        }
        catch {
            Logger.shared.error("❌ Failed to set header")
            return false
        }

        guard BluetoothManager.shared.isConnected else {
            Logger.shared.error("❌ Bluetooth Disconnected")
            return false
        }

        do {
            let result = try await BluetoothManager.shared.sendAndWait(
                "0100",
                timeout: .seconds(2)
            )
            let response = result.response

            let rx = response.raw.uppercased()

            if rx.contains("41") ||
                rx.contains("61") ||
                rx.contains("62") {

                Logger.shared.success("✅ ECU Responded")
                return true
            }

            if rx.contains("NO DATA") {
                Logger.shared.warning("⚠️ ECU Reachable but returned NO DATA")
                return true
            }

        } catch BluetoothManager.BluetoothError.timeout {
            Logger.shared.error("❌ ECU Response Timeout")
        }
        catch {
            Logger.shared.error("❌ Preflight Failed")
        }

        return false
    }
}
