//
//  OBDMode.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 28/06/2026.

import Foundation

enum OBDMode: String, CaseIterable, Identifiable {

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

    static let supportedScanModes: [OBDMode] = [
        .mode01,
        .mode21,
        .mode22
    ]

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

    var supportsBruteForce: Bool {
        Self.supportedScanModes.contains(self)
    }

    var pidDigits: Int {
        switch self {
        case .mode22, .mode23:
            return 4
        default:
            return 2
        }
    }

    var defaultStartPID: Int {
        switch self {
        case .mode22, .mode23:
            return 0x0000
        default:
            return 0x00
        }
    }

    var defaultEndPID: Int {
        switch self {
        case .mode22, .mode23:
            return 0xFFFF
        default:
            return 0xFF
        }
    }

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
            return UInt8(truncatingIfNeeded: 0x40 + Int(strtoul(rawValue, nil, 16)))
        }
    }
}
