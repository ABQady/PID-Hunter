//
//  ProbeRequest.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 11/07/2026.
//

enum ProbeRequest: CaseIterable {

    case mode01
    case mode02
    case mode03
    case mode04
    case mode05
    case mode06
    case mode07
    case mode08
    case mode09
    case mode0A
    case mode21
    case mode22

    var mode: OBDMode {
        switch self {
        case .mode01: return .mode01
        case .mode02: return .mode02
        case .mode03: return .mode03
        case .mode04: return .mode04
        case .mode05: return .mode05
        case .mode06: return .mode06
        case .mode07: return .mode07
        case .mode08: return .mode08
        case .mode09: return .mode09
        case .mode0A: return .mode0A
        case .mode21: return .mode21
        case .mode22: return .mode22
        }
    }

    var request: String {
        switch self {
        case .mode01: return "0100"
        case .mode02: return "0200"
        case .mode03: return "03"
        case .mode04: return "04"
        case .mode05: return "0500"
        case .mode06: return "0600"
        case .mode07: return "07"
        case .mode08: return "0800"
        case .mode09: return "0900"
        case .mode0A: return "0A"
        case .mode21: return "2100"
        case .mode22: return "220000"
        }
    }

    var description: String {
        mode.title
    }
}
