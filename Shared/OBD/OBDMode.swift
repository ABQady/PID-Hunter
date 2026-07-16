//
//  OBDMode.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 28/06/2026.

import Foundation


/// ScanCapability describes the request format used for a given OBD mode.
enum ScanCapability {
    case pid8
    case pid16
    case fixedCommand
    case infoType
    
    var pidWidth: Int {
        switch self {
        case .pid8: return 2
        case .pid16: return 4
        case .fixedCommand, .infoType: return 0
        }
    }
}

/// ScanStrategyType describes the execution algorithm used for scanning.
enum ScanStrategyType {
    case pid
    case fixedCommand
    case infoType
}

enum OBDMode: String, CaseIterable, Identifiable, Codable {

    case mode01 = "01"
    case mode02 = "02"
    case mode03 = "03"
    case mode04 = "04"
    case mode05 = "05"
    case mode06 = "06"
    case mode07 = "07"
    case mode08 = "08"
    case mode09 = "09"
    case mode0A = "0A"

    case mode21 = "21"
    case mode22 = "22"
    case mode23 = "23"


    var id: String {
        rawValue
    }

    var title: String {
        switch self {

        case .mode01:
            return "01 • Current Data"

        case .mode02:
            return "02 • Freeze Frame"

        case .mode03:
            return "03 • Stored DTCs"

        case .mode04:
            return "04 • Clear DTCs"

        case .mode05:
            return "05 • Oxygen Sensor Monitoring"

        case .mode06:
            return "06 • On-Board Monitoring"

        case .mode07:
            return "07 • Pending DTCs"

        case .mode08:
            return "08 • Actuator Control"

        case .mode09:
            return "09 • Vehicle Information"

        case .mode0A:
            return "0A • Permanent DTCs"

        case .mode21:
            return "21 • Manufacturer Data"

        case .mode22:
            return "22 • Extended Data"

        case .mode23:
            return "23 • Read Memory"
        }
    }

    var scanCapability: ScanCapability {
        switch self {
        case .mode01:
            return .pid8

        case .mode21:
            return .pid8

        case .mode22, .mode23:
            return .pid16

        case .mode09:
            return .infoType

        case .mode02,
             .mode03,
             .mode04,
             .mode05,
             .mode06,
             .mode07,
             .mode08,
             .mode0A:
            return .fixedCommand
        }
    }

    @inline(__always)
    var supportsPIDRange: Bool {
        switch scanCapability {
        case .pid8, .pid16:
            return true
        case .fixedCommand, .infoType:
            return false
        }
    }

    /// The scan strategy describes the execution algorithm for scanning this mode.
    var scanStrategy: ScanStrategyType {
        switch scanCapability {
        case .pid8, .pid16:
            return .pid
        case .fixedCommand:
            return .fixedCommand
        case .infoType:
            return .infoType
        }
    }


    var pidRange: ClosedRange<Int>? {
        switch scanCapability {
        case .pid8:
            return 0x00...0xFF
        case .pid16:
            return 0x0000...0xFFFF
        case .fixedCommand, .infoType:
            return nil
        }
    }

    @inline(__always)
    var responseService: UInt8 {
        switch self {
        case .mode01:
            return 0x41
        case .mode21:
            return 0x61
        case .mode22:
            return 0x62
        case .mode23:
            return 0x63
        default:
            return requestService &+ 0x40
        }
    }
    
    @inline(__always)
    var positiveResponsePrefix: String {
        String(format: "%02X", responseService)
    }

    @inline(__always)
    var identifierLength: Int {
        scanCapability.pidWidth
    }

    func payload(from response: String, request: String) -> String {
        let cleanedResponse = response.replacingOccurrences(of: " ", with: "")
        let cleanedRequest = request.replacingOccurrences(of: " ", with: "")

        guard !cleanedResponse.isEmpty else {
            return "—"
        }

        guard cleanedRequest.count >= 2 + identifierLength else {
            return cleanedResponse
        }

        let identifier = String(
            cleanedRequest
                .dropFirst(2)
                .prefix(identifierLength)
        )

        let expectedPrefix = positiveResponsePrefix + identifier

        guard cleanedResponse.hasPrefix(expectedPrefix) else {
            return cleanedResponse
        }

        let payloadHex = String(cleanedResponse.dropFirst(expectedPrefix.count))
        return payloadHex.isEmpty ? "—" : payloadHex
    }
    
    @inline(__always)
    var requestService: UInt8 {
        UInt8(rawValue, radix: 16) ?? 0
    }
    
    static let discoveryModes: [OBDMode] = [
        .mode01,
        .mode02,
        .mode03,
        .mode04,
        .mode05,
        .mode06,
        .mode07,
        .mode08,
        .mode09,
        .mode0A,
        .mode21,
        .mode22,
        .mode23
    ]
    
    /// Initial command used by Mode Discovery to determine whether this service is supported.
    var discoveryCommand: String {
        switch self {

        case .mode01,
             .mode02,
             .mode05,
             .mode06,
             .mode08,
             .mode09:
            return rawValue + "00"

        case .mode21:
            return rawValue + "00"

        case .mode22,
             .mode23:
            return rawValue + "0000"

        case .mode03,
             .mode04,
             .mode07,
             .mode0A:
            return rawValue
        }
    }

    var runtimeRequests: [String] {
        switch scanCapability {
        case .pid8, .pid16:
            return [discoveryCommand]

        case .fixedCommand:
            return [rawValue]

        case .infoType:
            return [
                rawValue + "00",
                rawValue + "02",
                rawValue + "04",
                rawValue + "06",
                rawValue + "08",
                rawValue + "0A"
            ]
        }
    }
}
