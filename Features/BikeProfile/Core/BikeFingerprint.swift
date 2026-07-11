//
//  BikeFingerprint.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 10/07/2026.
//
import Foundation

struct BikeFingerprint: Codable, Hashable {
    let header: String
    let protocolName: String
    let vinHex: String?
    let calibrationHex: String?
    var supportedHeaders: [String] = []

    private func normalized(_ value: String?) -> String {
        guard let value else {
            return "-"
        }

        return value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    var decodedVIN: String? {
        guard let vinHex else { return nil }

        let cleaned = vinHex
            .replacingOccurrences(of: " ", with: "")
            .uppercased()

        guard !cleaned.isEmpty,
              cleaned != String(repeating: "0", count: cleaned.count) else {
            return nil
        }

        return cleaned
    }

    var decodedCalibrationID: String? {
        guard let calibrationHex else { return nil }

        let hex = calibrationHex
            .replacingOccurrences(of: " ", with: "")

        guard hex.count.isMultiple(of: 2) else {
            return calibrationHex
        }

        var result = ""
        var index = hex.startIndex

        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            let byteString = String(hex[index..<next])

            guard let value = UInt8(byteString, radix: 16) else {
                return calibrationHex
            }

            if value == 0 {
                break
            }

            result.append(Character(UnicodeScalar(value)))
            index = next
        }

        return result.isEmpty ? calibrationHex : result
    }

    var id: String {
        [
            normalized(header),
            normalized(protocolName),
            normalized(vinHex),
            normalized(calibrationHex)
        ]
        .joined(separator: "_")
        .replacingOccurrences(of: " ", with: "_")
        .replacingOccurrences(of: "/", with: "-")
        .replacingOccurrences(of: ":", with: "-")
    }
    
}
