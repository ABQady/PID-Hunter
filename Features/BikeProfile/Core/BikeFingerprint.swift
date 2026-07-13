//
//  BikeFingerprint.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 10/07/2026.
//
import Foundation

struct BikeFingerprint: Codable, Hashable {
    let protocolName: String
    let vinHex: String?
    let calibrationHex: String?
    var supportedHeaders: [String] = []

    private func normalized(_ value: String?) -> String {
        guard let value else {
            return "-"
        }

        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        return cleaned.isEmpty ? "-" : cleaned
    }

    var decodedVIN: String? {
        guard let vinHex else { return nil }

        let hex = vinHex
            .replacingOccurrences(of: " ", with: "")
            .uppercased()

        guard !hex.isEmpty,
              hex.count.isMultiple(of: 2),
              hex != String(repeating: "0", count: hex.count) else {
            return nil
        }

        var result = ""
        var index = hex.startIndex

        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            let byteString = String(hex[index..<next])

            guard let value = UInt8(byteString, radix: 16) else {
                return vinHex
            }

            if value == 0 {
                break
            }

            result.append(Character(UnicodeScalar(value)))
            index = next
        }

        return result.isEmpty ? nil : result
    }

    var decodedCalibrationID: String {
        guard let calibrationHex else { return "" }

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

    func debugDescription() -> String {
        """
        protocol='\(protocolName)'
        calibration='\(decodedCalibrationID)'
        rawCalibration='\(calibrationHex ?? "nil")'
        supportedHeaders=\(supportedHeaders)
        """
    }

    var id: String {
        [
            normalized(protocolName),
            normalized(decodedCalibrationID)
        ]
        .joined(separator: "_")
        .replacingOccurrences(of: " ", with: "_")
        .replacingOccurrences(of: "/", with: "-")
        .replacingOccurrences(of: ":", with: "-")
    }
    
}
