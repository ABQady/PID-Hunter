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
            buffer.removeAll()
        }

        lastChunkTime = now
        buffer += chunk
        
        guard buffer.count <= maxBufferSize else {
            Logger.shared.debug("Assembler buffer overflow")
            Logger.shared.debug("Discarded buffer (\(buffer.count) bytes)")
            buffer.removeAll()
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

            if !trimmed.isEmpty {
                responses.append(ELMResponseParser.parse(trimmed))
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
