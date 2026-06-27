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
    case unknown
}

enum ELMResponseParser {

    static func parse(_ text: String) -> ELMResponse {

        let upper = text.uppercased()
        var type: ELMResponseType = .unknown
        var service: UInt8?
        var pid: UInt16?

        var tokens = upper
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
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
                service = 0x01
                if tokens.indices.contains(index + 1) {
                    pid = UInt16(tokens[index + 1], radix: 16)
                }
                payload = tokens
                     .dropFirst(index + 2)
                     .compactMap {UInt8($0, radix: 16)}
            case "61":
                type = .mode21
                service = 0x21
                if tokens.indices.contains(index + 1) {
                    pid = UInt16(tokens[index + 1], radix: 16)
                }
                payload = tokens
                     .dropFirst(index + 2)
                     .compactMap {UInt8($0, radix: 16)}
            case "62":
                type = .mode22
                service = 0x22
                if tokens.indices.contains(index + 2),
                   let high = UInt16(tokens[index + 1], radix: 16),
                   let low  = UInt16(tokens[index + 2], radix: 16) {

                    pid = (high << 8) | low
                }
                payload = tokens
                    .dropFirst(index + 3)
                    .compactMap {UInt8($0, radix: 16)}
            case "7F":
                type = .negative
            default:
                continue
            }
        }
        
        if type == .unknown {
            if upper.contains("NO DATA") {
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
