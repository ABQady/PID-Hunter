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

    private static let positiveServices: Set<String> = [
        "41", "61", "62"
    ]

    private enum Timing {
        static let headerSettle = Duration.milliseconds(100)
        static let retryDelay = Duration.milliseconds(500)
        static let headerTimeout = Duration.seconds(1)
        static let ecuTimeout = Duration.seconds(2)
        static let protocolTimeout = Duration.seconds(2)
    }

    private let maxECURetries = 2

    @inline(__always)
    private func ensureConnected() -> Bool {
        guard BluetoothManager.shared.isConnected else {
            Logger.shared.error("❌ Bluetooth Disconnected")
            return false
        }
        return true
    }

    @inline(__always)
    private func normalizeHeader(_ header: String) -> String {
        header
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

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

        let normalizedHeader = normalizeHeader(header)

        guard normalizedHeader.count == 6,
              normalizedHeader.allSatisfy(\.isHexDigit) else {
            Logger.shared.error("❌ Invalid Header")
            return false
        }

        do {
            let protocolResult = try await BluetoothManager.shared.sendAndWait(
                "ATDP",
                timeout: Timing.protocolTimeout
            )

            let protocolText = protocolResult.response.raw.uppercased()

            if protocolText.contains("?") {
                Logger.shared.warning("⚠️ Unable to identify protocol")
            } else {
                Logger.shared.info("Protocol: \(protocolResult.response.raw)")
            }

        } catch BluetoothManager.BluetoothError.timeout {
            Logger.shared.error("❌ ELM327 Timeout")
            return false

        } catch {
            Logger.shared.error("❌ Failed to communicate with ELM327")
            return false
        }

        guard ensureConnected() else {
            return false
        }

        do {

            _ = try await BluetoothManager.shared.sendAndWait(
                "ATSH \(normalizedHeader)",
                timeout: Timing.headerTimeout
            )

            try await Task.sleep(for: Timing.headerSettle)

            Logger.shared.info("Header: \(normalizedHeader)")

        } catch BluetoothManager.BluetoothError.timeout {
            Logger.shared.error("❌ Header Timeout")
            return false

        } catch {
            Logger.shared.error("❌ Failed to set header")
            return false
        }

        guard ensureConnected() else {
            return false
        }

        for attempt in 1...maxECURetries {

            do {

                let result = try await BluetoothManager.shared.sendAndWait(
                    "0100",
                    timeout: Timing.ecuTimeout
                )

                let rx = result.response.raw.uppercased()

                if Self.positiveServices.contains(where: rx.contains) {

                    if attempt > 1 {
                        Logger.shared.info("Recovered after retry")
                    }

                    Logger.shared.success("✅ ECU Responded")
                    return true
                }

                if rx.contains("NO DATA") {

                    if attempt > 1 {
                        Logger.shared.info("Recovered after retry")
                    }

                    Logger.shared.warning("⚠️ ECU Reachable but returned NO DATA")
                    return true
                }

            } catch BluetoothManager.BluetoothError.timeout {

                if attempt < maxECURetries {

                    Logger.shared.warning(
                        "⚠️ ECU timeout (attempt \(attempt)/\(maxECURetries)), retrying..."
                    )

                    try? await Task.sleep(for: Timing.retryDelay)
                    continue
                }

                Logger.shared.error("❌ ECU Response Timeout")

            } catch {

                if attempt < maxECURetries {

                    Logger.shared.warning(
                        "⚠️ ECU communication failed (attempt \(attempt)/\(maxECURetries)), retrying..."
                    )

                    try? await Task.sleep(for: Timing.retryDelay)
                    continue
                }

                Logger.shared.error("❌ Preflight Failed")
            }
        }

        return false
    }
}
