//
//  ELMResponseParser.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 27/06/2026.
//
import Foundation

struct ELMResponse {
    let raw: String
    let type: ELMResponseType
    let header: String?
    let service: UInt8?
    let pid: UInt16?
    let payload: [UInt8]
}

enum ELMResponseType {

    case mode01
    case mode21
    case mode22
    case negative
    case noData
    case stopped
    case busError
    case unableToConnect
    case searching
    case atResponse
    case unknown

    var requestMode: UInt8? {
        switch self {
        case .mode01: return 0x01
        case .mode21: return 0x21
        case .mode22: return 0x22
        default: return nil
        }
    }

    var pidBytes: Int {
        switch self {
        case .mode22: return 2
        case .mode01, .mode21: return 1
        default: return 0
        }
    }
}

enum ELMResponseParser {

    static func parse(_ text: String) -> ELMResponse {

        let upper = text.uppercased()
        var type: ELMResponseType = .unknown
        var service: UInt8?
        var pid: UInt16?

        let normalized = upper
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")

        let spaced = normalized.contains(" ")
            ? normalized
            : normalized.chunked(into: 2).joined(separator: " ")

        var tokens = spaced
            .split(separator: " ")
            .map(String.init)

        var header: String?
        
        if tokens.count >= 5,
           tokens[0].count == 2,
           UInt8(tokens[0], radix: 16) != nil,
           let _ = UInt8(tokens[1], radix: 16),
           let _ = UInt8(tokens[2], radix: 16),
           ["41", "61", "62", "7F"].contains(tokens[3]) {

            header = "\(tokens[0]) \(tokens[1]) \(tokens[2])"
            tokens.removeFirst(3)
        }
        var payload: [UInt8] = []
        
        for (index, token) in tokens.enumerated() {
            switch token {
            case "41":
                type = .mode01
            case "61":
                type = .mode21
            case "62":
                type = .mode22
            case "7F":
                type = .negative
                continue
            default:
                continue
            }
            service = type.requestMode
            let pidLength = type.pidBytes
            if pidLength == 1 {
                if tokens.indices.contains(index + 1) {
                    pid = UInt16(tokens[index + 1], radix: 16)
                }
            } else if pidLength == 2 {
                if tokens.indices.contains(index + 2),
                   let high = UInt16(tokens[index + 1], radix: 16),
                   let low  = UInt16(tokens[index + 2], radix: 16) {
                    pid = (high << 8) | low
                }
            }
            payload = tokens
                .dropFirst(index + 1 + pidLength)
                .compactMap { UInt8($0, radix: 16) }
            break
        }
        
        if type == .unknown {
            if upper == "OK"
                || upper.hasPrefix("ELM")
                || upper.contains("ISO")
                || upper.contains("KWP")
                || upper.contains("CAN")
                || upper.contains("J1850") {

                type = .atResponse

            } else if upper.contains("NO DATA") {
                type = .noData
            } else if upper.contains("STOPPED") {
                type = .stopped
            } else if upper.contains("BUS ERROR") {
                type = .busError
            } else if upper.contains("UNABLE TO CONNECT") {
                type = .unableToConnect
            } else if upper.contains("SEARCHING") {
                type = .searching
            }
        }
        
        return ELMResponse(
            raw: text,
            type: type,
            header: header,
            service: service,
            pid: pid,
            payload: payload
        )
    }
}
extension String {

    func chunked(into size: Int) -> [String] {

        stride(from: 0, to: count, by: size).map {

            let start = index(startIndex, offsetBy: $0)
            let end = index(start, offsetBy: size, limitedBy: endIndex) ?? endIndex

            return String(self[start..<end])
        }
    }
}
