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
    case unknownFrame

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

    private static let ecuServiceTokens: Set<String> = [
        "41", "61", "62", "7F"
    ]

    private static let informationalMarkers = [
        "BUS INIT:",
        "BUS INIT",
        "SEARCHING...",
        "SEARCHING",
    ]

    static func parse(_ text: String) -> ELMResponse {

        let upper = text.uppercased()
        let compact = upper
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
        // Strip informational ELM prefixes that can precede a valid ECU frame.
        var sanitized = upper
        for marker in informationalMarkers {
            sanitized = sanitized.replacingOccurrences(of: marker, with: " ")
        }
        var type: ELMResponseType = .unknown
        var service: UInt8?
        var pid: UInt16?

        let normalized = sanitized
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")

        let spaced = normalized.contains(" ")
            ? normalized
            : normalized.chunked(into: 2).joined(separator: " ")

        var tokens = spaced
            .split(separator: " ")
            .map(String.init)
        tokens.removeAll { $0.isEmpty }
        
        tokens = tokens.flatMap { token in
            let cleaned = token.trimmingCharacters(in: .whitespaces)

            guard cleaned.count > 2,
                  cleaned.count.isMultiple(of: 2),
                  cleaned.allSatisfy({ $0.isHexDigit })
            else {
                return [cleaned]
            }

            return cleaned.chunked(into: 2)
        }
        
        if tokens.isEmpty {
            if upper.contains("OK") || upper.contains("ELM") || upper.hasPrefix("AT") {
                Logger.shared.debug("Parser → atResponse (empty token fallback)")
                return ELMResponse(
                    raw: text,
                    type: .atResponse,
                    header: nil,
                    service: nil,
                    pid: nil,
                    payload: []
                )
            }
            return ELMResponse(
                raw: text,
                type: .unknown,
                header: nil,
                service: nil,
                pid: nil,
                payload: []
            )
        }
        
        while let first = tokens.first,
              first.hasPrefix("AT") {
            tokens.removeFirst()
        }
        var header: String?
        
        if tokens.count >= 4,
           tokens[0].count == 2,
           UInt8(tokens[0], radix: 16) != nil,
           UInt8(tokens[1], radix: 16) != nil,
           UInt8(tokens[2], radix: 16) != nil,
           ecuServiceTokens.contains(tokens[3]) {

            header = "\(tokens[0].uppercased()) \(tokens[1].uppercased()) \(tokens[2].uppercased())"
            tokens.removeFirst(3)
        }
        var payload: [UInt8] = []
        
        if upper.contains("NO DATA") {
            type = .noData
        } else if upper.contains("UNABLE TO CONNECT") {
            type = .unableToConnect
        } else if upper.contains("BUS ERROR") {
            type = .busError
        } else if upper.contains("STOPPED") {
            type = .stopped
        }
        
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
                let negativeResponse = ELMResponse(
                    raw: text,
                    type: .negative,
                    header: header,
                    service: nil,
                    pid: nil,
                    payload: tokens.dropFirst(index + 1).compactMap { UInt8($0, radix: 16) }
                )
                Logger.shared.debug(
                    "Parser → negative | Header=\(header ?? "-")"
                )

                return negativeResponse
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
            
            Logger.shared.debug(
                "Parser → \(type) | Header=\(header ?? "-") | Service=\(service.map { String(format: "%02X", $0) } ?? "-") | PID=\(pid.map { String(format: "%04X", $0) } ?? "-")"
            )

            return ELMResponse(
                raw: text,
                type: type,
                header: header,
                service: service,
                pid: pid,
                payload: payload
            )
        }
        
        let hasHeader =
            header != nil ||
            (tokens.count >= 3 &&
             tokens[0].allSatisfy(\.isHexDigit) &&
             tokens[1].allSatisfy(\.isHexDigit) &&
             tokens[2].allSatisfy(\.isHexDigit))

        type = hasHeader ? .unknownFrame : .unknown
        
        if type == .unknown {
            let lines = upper
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            let hasATCommandEcho = lines.contains {
                $0.hasPrefix("AT") && $0.count > 2
            }

            let hasATReply = compact.contains("OK")
                || upper.contains("ELM327")
                || upper.contains("ELM")
                || upper.contains("ISO")
                || upper.contains("KWP")
                || upper.contains("CAN")
                || upper.contains("J1850")

            if hasATCommandEcho || hasATReply {
                type = .atResponse
            } else if upper.contains("SEARCHING") {
                type = .searching
            }
        }
        
        if type == .negative {
            service = nil
            pid = nil
        }
        
        Logger.shared.debug("Parser → \(type) | Header=\(header ?? "-") | Service=\(service.map { String(format: "%02X", $0) } ?? "-") | PID=\(pid.map { String(format: "%04X", $0) } ?? "-")")
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
extension ELMResponse {
    var isSuspicious: Bool {
        switch type {
        case .mode01, .mode21, .mode22:
            return payload.isEmpty
        default:
            return false
        }
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
