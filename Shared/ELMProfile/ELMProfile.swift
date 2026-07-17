//
//  ELMProfile.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 17/07/2026.
//


import Foundation

struct ELMFingerprint: Codable, Hashable, LosslessStringConvertible {
    let id: String

    init(id: String) {
        self.id = id
    }

    init(_ description: String) {
        self.id = description
    }

    var description: String { id }
}

struct ELMCommandResult: Codable, Hashable {
    let command: ELMCommand
    let response: String
    let supported: Bool
    let latency: TimeInterval?
}

struct ELMProfile: Identifiable, Codable, Hashable {
    var id: String { fingerprint.id }

    let fingerprint: ELMFingerprint
    let firmware: String?
    let deviceIdentifier: String?
    let deviceDescription: String?
    let voltage: Double?
    let protocolDescription: String?
    let protocolNumber: String?

    let commandResults: [ELMCommandResult]

    let discoveredAt: Date

    var supportsCAN: Bool {
        protocolDescription?.localizedCaseInsensitiveContains("CAN") == true
    }

    var supportsISO: Bool {
        protocolDescription?.localizedCaseInsensitiveContains("ISO") == true
    }

    var supportedCommands: [ELMCommand] {
        commandResults.filter(\.supported).map(\.command)
    }

    var unsupportedCommands: [ELMCommand] {
        commandResults.filter { !$0.supported }.map(\.command)
    }

    var standardCommands: [ELMCommand] {
        supportedCommands.filter(\.isStandard)
    }

    var optionalCommands: [ELMCommand] {
        supportedCommands.filter(\.isOptional)
    }

    var vendorCommands: [ELMCommand] {
        supportedCommands.filter(\.isVendorSpecific)
    }

    var supportRate: Double {
        guard !commandResults.isEmpty else { return 0 }
        let supported = commandResults.filter(\.supported).count
        return Double(supported) / Double(commandResults.count)
    }
}

extension ELMProfile {
    static let empty = ELMProfile(
        fingerprint: ELMFingerprint(id: UUID().uuidString),
        firmware: nil,
        deviceIdentifier: nil,
        deviceDescription: nil,
        voltage: nil,
        protocolDescription: nil,
        protocolNumber: nil,
        commandResults: [],
        discoveredAt: .now
    )
}
