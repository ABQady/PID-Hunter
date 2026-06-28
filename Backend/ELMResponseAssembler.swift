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

    func append(_ chunk: String) -> [ELMResponse] {
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

        // Ignore ELM informational chatter until a complete response is received.
        // These messages may legitimately precede a real ECU frame.
        buffer = buffer.replacingOccurrences(of: "\rBUS INIT:", with: "\rBUS INIT: ")
        buffer = buffer.replacingOccurrences(of: "\rSEARCHING...", with: "\rSEARCHING... ")

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
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmed.isEmpty else {
                continue
            }

            let parsed = ELMResponseParser.parse(trimmed)
            let upper = trimmed.uppercased()
            let compact = upper.replacingOccurrences(of: " ", with: "")

            let hasECUFrame = compact.contains("4100") ||
                              compact.contains("41") ||
                              compact.contains("61") ||
                              compact.contains("62") ||
                              compact.contains("7F")

            let isELMChatter = upper.contains("BUS INIT") ||
                               upper.contains("SEARCHING") ||
                               upper.contains("ELM327") ||
                               upper.contains("ATI") ||
                               upper == "OK" ||
                               upper.hasPrefix("ISO ") ||
                               upper.hasPrefix("KWP")

            if isELMChatter && !hasECUFrame {
                Logger.shared.debug("Assembler ignored informational response: \(trimmed)")
                continue
            }

            if parsed.type == .unknown && !hasECUFrame {
                Logger.shared.debug("Assembler discarded unknown response: \(trimmed)")
                continue
            }

            Logger.shared.debug("Assembler accepted response: \(parsed.type)")
            responses.append(parsed)
       }
        if !responses.isEmpty {
            Logger.shared.debug(
                "Assembler completed \(responses.count) response(s)"
            )
        }
        return responses
    }
}
