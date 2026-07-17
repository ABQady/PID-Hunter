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


    @inline(__always)
    private func normalized(_ value: String?) -> String {
        guard let value else {
            return "-"
        }

        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        return cleaned.isEmpty ? "-" : cleaned
    }

    // VIN and Calibration are already decoded by ELMResponseParser.
    // BikeFingerprint stores and displays the final values only.
    var decodedVIN: String? {
        let value = vinHex?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == true ? nil : value
    }

    var decodedCalibrationID: String {
        calibrationHex?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""
    }

    func debugDescription() -> String {
        """
        protocol='\(protocolName)'
        calibration='\(decodedCalibrationID)'
        rawCalibration='\(calibrationHex ?? "nil")'
        decodedVIN='\(decodedVIN ?? "nil")'
        supportedHeaders=\(supportedHeaders)
        """
    }

    var id: String {
        normalized(decodedCalibrationID)
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
    }
    
}
