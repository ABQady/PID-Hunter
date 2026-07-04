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

            await Logger.shared.debug("Assembler timeout")
            await Logger.shared.debug("Discarded buffer (\(buffer.count) bytes)")
            await Logger.shared.debug(buffer)
            buffer.removeAll(keepingCapacity: true)
        }

        lastChunkTime = now
        buffer += chunk

        guard buffer.count <= maxBufferSize else {
            await Logger.shared.debug("Assembler buffer overflow")
            await Logger.shared.debug("Discarded buffer (\(buffer.count) bytes)")
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
            
            switch parsed.type {
            case .unknown:
                await Logger.shared.debug("Assembler discarded unknown response: \(trimmed)")

            default:
                await Logger.shared.debug(
                    "Assembler accepted \(parsed.type): \(trimmed)"
                )
                responses.append(parsed)
            }
       }
        if !responses.isEmpty {
            await Logger.shared.debug(
                "Assembler completed \(responses.count) response(s)"
            )
        }
        return responses
    }
}
