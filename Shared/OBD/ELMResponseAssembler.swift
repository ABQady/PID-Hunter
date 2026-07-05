//
//  ELMResponseAssembler.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 27/06/2026.
//
import Foundation

@MainActor
final class ELMResponseAssembler {

    static let shared = ELMResponseAssembler()
    private init() {}
    private var buffer = ""
    private var lastChunkTime = Date()
    private let timeout: TimeInterval = 2.0
    private let maxBufferSize = 8192

    func clear() {
        buffer.removeAll()
        lastChunkTime = Date()
    }

    func append(_ chunk: String) async -> [ELMResponse] {
        let now = Date()
        if !buffer.isEmpty &&
            now.timeIntervalSince(lastChunkTime) > timeout {

            Logger.shared.debug("Assembler timeout")
            Logger.shared.debug("Discarded buffer (\(buffer.count) bytes)")
            Logger.shared.debug(buffer)
            buffer.removeAll(keepingCapacity: true)
        }

        lastChunkTime = now
        buffer += chunk
        Logger.shared.debug("Assembler RX chunk (\(chunk.count) bytes): \(chunk.debugDescription)")

        guard buffer.count <= maxBufferSize else {
            Logger.shared.debug("Assembler buffer overflow")
            Logger.shared.debug("Discarded buffer (\(buffer.count) bytes)")
            buffer.removeAll(keepingCapacity: true)
            return []
        }

        // Extract every complete ELM response ending with '>'
        var responses: [ELMResponse] = []
        while let range = buffer.range(of: ">") {

            let response = String(buffer[..<range.upperBound])

            buffer.removeSubrange(..<range.upperBound)

            let trimmed = response
                .replacingOccurrences(of: ">", with: "")
                .replacingOccurrences(of: "\0", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmed.isEmpty else {
                continue
            }

            Logger.shared.debug("Assembler complete response: \(trimmed.debugDescription)")
            let parsed = ELMResponseParser.parse(trimmed)
            let header = parsed.header ?? "-"
            let service = parsed.service.map { String(format: "%02X", $0) } ?? "-"
            let pid = parsed.pid.map { String(format: "%04X", $0) } ?? "-"
            let payload = parsed.payload.map { String(format: "%02X", $0) }.joined(separator: " ")
            Logger.shared.debug(
                "Assembler parsed → type=\(parsed.type) | header=\(header) | service=\(service) | pid=\(pid) | payload=[\(payload)]"
            )
            switch parsed.type {
            case .unknown:
                Logger.shared.debug("Assembler ignored non-ECU text: \(trimmed)")
                continue
            case .unknownFrame:
                Logger.shared.debug("Assembler accepted UNKNOWN ECU frame: \(trimmed)")
                responses.append(parsed)
            default:
                Logger.shared.debug(
                    "Assembler accepted \(parsed.type): \(trimmed)"
                )
                responses.append(parsed)
            }
       }
        if !responses.isEmpty {
            Logger.shared.debug(
                "Assembler completed \(responses.count) response(s)"
            )
        }
        return responses
    }
}
