//
//  ELMProfileBuilder.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 17/07/2026.
//

import Foundation

struct ELMProfileBuilder {

    private typealias Lookup = [ELMCapability: ELMCommandResult]

    func build(from results: [ELMCommandResult]) -> ELMProfile {
        let lookup: Lookup = Dictionary(
            uniqueKeysWithValues: results.compactMap { result -> (ELMCapability, ELMCommandResult)? in
                guard let capability = result.command.capability else {
                    return nil
                }
                return (capability, result)
            }
        )

        return ELMProfile(
            fingerprint: fingerprint(from: lookup),
            firmware: lookup[.firmware]?.response,
            deviceIdentifier: lookup[.deviceIdentifier]?.response,
            deviceDescription: lookup[.deviceDescription]?.response,
            voltage: parseVoltage(lookup[.voltage]?.response),
            protocolDescription: lookup[.protocolDescription]?.response,
            protocolNumber: lookup[.protocolNumber]?.response,
            commandResults: results,
            discoveredAt: .now
        )
    }

    private func fingerprint(from lookup: Lookup) -> String {
        let signature = lookup.values
            .filter(\.supported)
            .sorted { $0.command.command < $1.command.command }
            .map { "\($0.command.command)=\($0.response.trimmingCharacters(in: .whitespacesAndNewlines))" }
            .joined(separator: "|")

        return String(signature.hashValue, radix: 16).uppercased()
    }

    private func parseVoltage(_ response: String?) -> Double? {
        guard let response else { return nil }
        let cleaned = response
            .replacingOccurrences(of: "V", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(cleaned)
    }
}
