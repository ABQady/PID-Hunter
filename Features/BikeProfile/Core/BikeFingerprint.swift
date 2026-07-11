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
    let ecuIdentifier: String?
    let calibrationIdentifier: String?
    var supportedHeaders: [String] = []

    private func normalized(_ value: String?) -> String {
        guard let value else {
            return "-"
        }

        return value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    var id: String {
        [
            normalized(header),
            normalized(protocolName),
            normalized(ecuIdentifier),
            normalized(calibrationIdentifier)
        ]
        .joined(separator: "_")
        .replacingOccurrences(of: " ", with: "_")
        .replacingOccurrences(of: "/", with: "-")
        .replacingOccurrences(of: ":", with: "-")
    }
    
}
