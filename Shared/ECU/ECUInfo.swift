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

    @Published var ecuName = "Unknown"
    @Published var elmVersion = "-"
    @Published var protocolName = "-"
    @Published var ecuIdentifier = ""
    @Published var calibrationIdentifier = ""
    @Published var header = "-"
    @Published var status = "-"
    @Published var services = SupportedServices()
    @Published var lastConnected: Date?

    private init() {}

    func clear() {
        ecuName = "Unknown"
        elmVersion = "-"
        protocolName = "-"
        ecuIdentifier = ""
        calibrationIdentifier = ""
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
        BikeFingerprint(
            header: normalized(header) ?? "",
            protocolName: normalized(protocolName) ?? "",
            vinHex: normalized(ecuIdentifier),
            calibrationHex: normalized(calibrationIdentifier)
        )
    }
    
    var hasFingerprint: Bool {
        normalized(protocolName) != nil &&
        normalized(header) != nil
    }
}
