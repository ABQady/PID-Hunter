//
//  ELMResponseParser.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 27/06/2026.
//
import Foundation

struct ELMResponse: Codable, Equatable, Hashable {
    let raw: String
    let type: ELMResponseType
    let header: String?
    var service: UInt8? {
        switch type {
        case .positive(let service), .negative(let service):
            return service
        default:
            return nil
        }
    }
    let pid: UInt16?
    let payload: [UInt8]
    
}


enum ELMResponseType: Codable, Equatable, Hashable {
    case noData
    case stopped
    case busError
    case unableToConnect
    case searching
    case atResponse
    case unknown
    case positive(service: UInt8)
    case negative(service: UInt8)
    case partialFrame
}

enum ELMResponseParser {

    private static let informationalMarkers = [
        "BUS INIT:",
        "BUS INIT",
        "SEARCHING...",
        "SEARCHING",
        "BUS INIT: OK",
        "BUS INIT...OK",
    ]



    static func parse(_ text: String) -> ELMResponse {

        let upper = text.uppercased()
        
        let informationalOnly = informationalMarkers.contains { upper.trimmingCharacters(in: .whitespacesAndNewlines) == $0 }
        if informationalOnly {
            return ELMResponse(
                raw: text,
                type: .searching,
                header: nil,
                pid: nil,
                payload: []
            )
        }

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
                Logger.shared.verbose("Parser → atResponse (empty token fallback)")
                return ELMResponse(
                    raw: text,
                    type: .atResponse,
                    header: nil,
                    pid: nil,
                    payload: []
                )
            }
            return ELMResponse(
                raw: text,
                type: .unknown,
                header: nil,
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
           tokens[1].count == 2,
           tokens[2].count == 2,
           let _ = UInt8(tokens[0], radix: 16),
           let _ = UInt8(tokens[1], radix: 16),
           let _ = UInt8(tokens[2], radix: 16),
           let serviceByte = UInt8(tokens[3], radix: 16),
           serviceByte == 0x7F || serviceByte >= 0x40
        {
            header = "\(tokens[0].uppercased()) \(tokens[1].uppercased()) \(tokens[2].uppercased())"
            tokens.removeFirst(3)
        }
        
        var payload: [UInt8] = []
        
        if upper.contains("NO DATA") {
            type = .noData
            return ELMResponse(
                    raw: text,
                    type: type,
                    header: header,
                    pid: nil,
                    payload: []
                )
        } else if upper.contains("UNABLE TO CONNECT") {
            Logger.shared.warning("Parser → unableToConnect")
            type = .unableToConnect
            return ELMResponse(
                    raw: text,
                    type: type,
                    header: header,
                    pid: nil,
                    payload: []
                )
        } else if upper.contains("BUS ERROR") {
            Logger.shared.warning("Parser → busError")
            type = .busError
            return ELMResponse(
                    raw: text,
                    type: type,
                    header: header,
                    pid: nil,
                    payload: []
                )
        } else if upper.contains("STOPPED") {
            type = .stopped
            return ELMResponse(
                    raw: text,
                    type: type,
                    header: header,
                    pid: nil,
                    payload: []
                )
        }
        
        // Deterministic parsing based on the first protocol byte
        guard let firstToken = tokens.first else {
            if upper.contains("OK") || upper.contains("ELM") || upper.hasPrefix("AT") {
                Logger.shared.verbose("Parser → atResponse (empty token fallback)")
                return ELMResponse(
                    raw: text,
                    type: .atResponse,
                    header: header,
                    pid: nil,
                    payload: []
                )
            }
            return ELMResponse(
                raw: text,
                type: .unknown,
                header: header,
                pid: nil,
                payload: []
            )
        }

        // Handle negative response only if the first protocol byte is 7F
        if firstToken == "7F" {
            guard tokens.count >= 3,
                  let requestedService = UInt8(tokens[1], radix: 16)
            else {
                return ELMResponse(raw: text, type: .unknown, header: header, pid: nil, payload: [])
            }

            Logger.shared.verbose(
                "Parser → negative | Header=\(header ?? "-") | Service=\(String(format: "%02X", requestedService))"
            )

            return ELMResponse(
                raw: text,
                type: .negative(service: requestedService),
                header: header,
                pid: nil,
                payload: tokens.dropFirst(2).compactMap { UInt8($0, radix: 16) }
            )
        }

        // Parse positive responses ONLY from the first protocol byte
        guard let responseService = UInt8(firstToken, radix: 16),
              (0x40...0x7E).contains(responseService)
        else {
            // fall through to AT/searching/unknown logic below
            let lines = upper
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            let hasATCommandEcho = lines.contains {
                $0.hasPrefix("AT") && $0.count > 2
            }

            let hasATReply = compact.contains("OK")
                || upper.contains("ELM327")
                || upper.hasPrefix("ELM")
                || upper.contains("ISO")
                || upper.contains("KWP")
                || upper.contains("CAN")
                || upper.contains("J1850")

            if hasATCommandEcho || hasATReply {
                type = .atResponse
            } else if upper.contains("SEARCHING") {
                type = .searching
            } else {
                type = .unknown
            }

            Logger.shared.verbose("Parser → \(type) | Header=\(header ?? "-") | Service=\(service.map { String(format: "%02X", $0) } ?? "-") | PID=\(pid.map { String(format: "%04X", $0) } ?? "-")")
            return ELMResponse(
                raw: text,
                type: type,
                header: header,
                pid: pid,
                payload: payload
            )
        }

        let requestService = responseService - 0x40
        service = requestService

        let definition = ProtocolDefinition.kwp
        let pidLength = definition.identifierLength(for: requestService)

        type = .positive(service: requestService)

        // PID parsing: identifier starts at token index 1
        if pidLength == 1 {
            if tokens.indices.contains(1) {
                pid = UInt16(tokens[1], radix: 16)
            }
        } else if pidLength == 2 {
            if tokens.indices.contains(2),
               let high = UInt16(tokens[1], radix: 16),
               let low  = UInt16(tokens[2], radix: 16) {
                pid = (high << 8) | low
            }
        }

        Logger.shared.info("""
🔎 Parsed Response
Service : \(String(format: "%02X", requestService))
PID Len : \(pidLength)
PID     : \(pid.map { String(format: "%04X", $0) } ?? "-")
""")

        let identifier = Array(
            tokens
                .dropFirst(1)
                .prefix(pidLength)
                .compactMap { UInt8($0, radix: 16) }
        )

        let frames = ProtocolFrameParser.parse(
            tokens: tokens,
            requestService: requestService,
            definition: definition
        )

        Logger.shared.info("🔎 Parsed \(frames.count) response frame(s)")

        payload = ProtocolFrameParser.assemblePayload(
            from: frames,
            identifier: identifier
        )

        Logger.shared.info(
            "🔎 Parsed Payload: \(payload.map { String(format: "%02X", $0) }.joined(separator: " "))"
        )

        Logger.shared.verbose(
            "Parser → \(type) | Header=\(header ?? "-") | Service=\(service.map { String(format: "%02X", $0) } ?? "-") | PID=\(pid.map { String(format: "%04X", $0) } ?? "-")"
        )

        return ELMResponse(
            raw: text,
            type: type,
            header: header,
            pid: pid,
            payload: payload
        )
    }
}
extension ELMResponse {
    var isSuspicious: Bool {
        if case .positive = type {
            return payload.isEmpty
        }
        return false
    }

    var formatByte: UInt8? {
        guard let header else { return nil }
        let bytes = header.split(separator: " ")
        guard bytes.count == 3 else { return nil }
        return UInt8(bytes[0], radix: 16)
    }

    var respondingAddress: UInt8? {
        guard let header else { return nil }
        let bytes = header.split(separator: " ")
        guard bytes.count == 3 else { return nil }
        return UInt8(bytes[1], radix: 16)
    }

    var targetAddress: UInt8? {
        guard let header else { return nil }
        let bytes = header.split(separator: " ")
        guard bytes.count == 3 else { return nil }
        return UInt8(bytes[2], radix: 16)
    }
}
extension ELMResponse {

    @inline(__always)
    private func asciiPayload() -> String? {
        Logger.shared.info("""
🔎 ASCII Payload
Service : \(service.map { String(format: "%02X", $0) } ?? "-")
PID     : \(pid.map { String(format: "%04X", $0) } ?? "-")
Payload : \(payload.map { String(format: "%02X", $0) }.joined(separator: " "))
""")

        let printable = payload.filter { 0x20...0x7E ~= $0 }

        guard !printable.isEmpty else {
            return nil
        }

        let decoded = String(bytes: printable, encoding: .ascii)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        Logger.shared.info("🔎 ASCII Decoded: \(decoded ?? "nil")")

        return decoded
    }

    var asciiString: String? {
        asciiPayload()
    }

    var vin: String? {
        guard service == 0x09, pid == 0x02 else {
            return nil
        }
        return asciiPayload()
    }

    var calibrationID: String? {
        guard service == 0x09, pid == 0x04 else {
            return nil
        }
        return asciiPayload()
    }

    var ecuName: String? {
        guard service == 0x09, pid == 0x0A else {
            return nil
        }
        return asciiPayload()
    }
}
extension String {

    func chunked(into size: Int) -> [String] {

        guard size > 0 else {
            return []
        }

        return stride(from: 0, to: count, by: size).map {

            let start = index(startIndex, offsetBy: $0)
            let end = index(start, offsetBy: size, limitedBy: endIndex) ?? endIndex

            return String(self[start..<end])
        }
    }
}
