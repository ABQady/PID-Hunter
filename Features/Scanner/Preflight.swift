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

    private enum Timing {
        static let headerSettle = Duration.milliseconds(750)
        static let retryDelay = Duration.milliseconds(750)
        static let headerTimeout = Duration.seconds(3)
        static let ecuTimeout = Duration.seconds(3)
        static let protocolTimeout = Duration.seconds(3)
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

    func run(header: String, mode: OBDMode) async -> Bool {

        Logger.shared.info("========== PREFLIGHT ==========")

        guard ensureConnected() else {
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

        guard !Task.isCancelled else {
            Logger.shared.warning("⚠️ Preflight Cancelled")
            return false
        }

        guard normalizedHeader.count == 6,
              normalizedHeader.allSatisfy(\.isHexDigit) else {
            Logger.shared.error("❌ Invalid Header")
            return false
        }

        guard let probe = ProbeRequest.forMode(mode) else {
            Logger.shared.error("❌ No probe defined for selected mode")
            return false
        }

//        guard await ELM327.shared.initializeELM() else {
//            Logger.shared.error("❌ Failed to initialize ELM")
//            return false
//        }

        guard ensureConnected() else {
            return false
        }

        do {

            _ = try await BluetoothManager.shared.sendAndWait(
                "ATSH \(normalizedHeader)",
                timeout: Timing.headerTimeout
            )

            try await Task.sleep(for: Timing.headerSettle)
            guard !Task.isCancelled else {
                Logger.shared.warning("⚠️ Preflight Cancelled")
                return false
            }

            Logger.shared.verbose(.setup, "Header: \(normalizedHeader)")

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

            guard ensureConnected() else {
                return false
            }

            do {

                let result = try await BluetoothManager.shared.sendAndWait(
                    probe.request,
                    timeout: Timing.ecuTimeout
                )

                let rx = result.response.raw.uppercased()
                let response = result.response

                Logger.shared.verbose(.discovery, "Probe response type: \(response.type)")
                Logger.shared.verbose(.communication, "Probe raw response: \(rx)")

                switch response.type {

                case .positive:
                    if attempt > 1 {
                        Logger.shared.verbose(.telemetry, "Recovered after retry")
                    }
                    Logger.shared.success("✅ ECU Responded")
                    return true

                case .negative:
                    Logger.shared.success("✅ ECU Responded (Negative Response)")
                    return true

                case .noData:
                    if attempt > 1 {
                        Logger.shared.verbose(.telemetry, "Recovered after retry")
                    }
                    Logger.shared.warning("⚠️ ECU Reachable (NO DATA)")
                    return true

                case .partialFrame:
                    Logger.shared.success("✅ ECU Responded (Partial Frame)")
                    return true

                default:
                    break
                }

                // Fallback for adapters that return plain text instead of a parsed response.
                if rx.contains(probe.responseService) || rx.contains("NO DATA") {
                    Logger.shared.success("✅ ECU Responded (Raw Match)")
                    return true
                }

                Logger.shared.verbose(.discovery, "Unexpected response type: \(response.type)")

            } catch BluetoothManager.BluetoothError.timeout {

                if attempt < maxECURetries {

                    Logger.shared.warning(
                        "⚠️ ECU timeout (attempt \(attempt)/\(maxECURetries)), retrying..."
                    )

                    try? await Task.sleep(for: Timing.retryDelay)
                    guard !Task.isCancelled else {
                        Logger.shared.warning("⚠️ Preflight Cancelled")
                        return false
                    }
                    continue
                }

                Logger.shared.error("❌ ECU Response Timeout")

            } catch {

                if attempt < maxECURetries {

                    Logger.shared.warning(
                        "⚠️ ECU communication failed (attempt \(attempt)/\(maxECURetries)), retrying..."
                    )

                    try? await Task.sleep(for: Timing.retryDelay)
                    guard !Task.isCancelled else {
                        Logger.shared.warning("⚠️ Preflight Cancelled")
                        return false
                    }
                    continue
                }

                Logger.shared.error("❌ Preflight Failed")
            }
        }

        return false
    }
}
