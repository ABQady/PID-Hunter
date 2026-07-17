//
//  ECUInfo.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 27/06/2026.
//
import Foundation

struct SupportedServices {
    private(set) var services: [String] = []

    mutating func insert(_ service: String) {
        guard !services.contains(service) else {
            return
        }

        services.append(service)
        services.sort()
    }

    mutating func removeAll() {
        services.removeAll(keepingCapacity: true)
    }
}

@MainActor
final class ECUInfo: ObservableObject {

    static let shared = ECUInfo()

    @Published var adapterDescription = "-"
    @Published var elmVersion = "-"
    @Published var ecuName = "-"
    @Published var protocolName = "-"
    @Published var ecuIdentifier = "-"
    @Published var calibrationIdentifier = "-"
    @Published var vinIndentifier = "-"
    @Published var header = "-"
    @Published var status = "-"
    @Published var services = SupportedServices()
    @Published var lastConnected: Date?

    private init() {}

    func clear() {
        ecuName = "-"
        adapterDescription = "-"
        elmVersion = "-"
        protocolName = "-"
        ecuIdentifier = "-"
        calibrationIdentifier = "-"
        vinIndentifier = "-"
        header = "-"
        status = "-"
        services.removeAll()
        lastConnected = nil
    }
    
    func addService(_ service: UInt8?) {

        guard let service else {
            return
        }

        let value = String(format: "%02X", service)

        services.insert(value)
    }

    private func normalized(_ value: String) -> String? {
        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty,
              trimmed != "-",
              trimmed.uppercased() != "UNKNOWN" else {
            return nil
        }

        return trimmed
    }

    var fingerprint: BikeFingerprint {
        let normalizedProtocol = normalized(protocolName) ?? ""
        let normalizedVIN = normalized(vinIndentifier)
        let normalizedCalibration = normalized(calibrationIdentifier)

        Logger.shared.info("""
        🧬 Fingerprint
        Raw Protocol        = '\(protocolName)'
        Raw VIN             = '\(vinIndentifier)'
        Raw Calibration     = '\(calibrationIdentifier)'

        Normalized Protocol = '\(normalizedProtocol)'
        Normalized VIN      = '\(normalizedVIN ?? "nil")'
        Normalized Calib    = '\(normalizedCalibration ?? "nil")'
        """)

        return BikeFingerprint(
            protocolName: normalizedProtocol,
            vinHex: normalizedVIN,
            calibrationHex: normalizedCalibration
        )
    }

    var hasFingerprint: Bool {
        normalized(protocolName) != nil &&
        normalized(calibrationIdentifier) != nil
    }
}
