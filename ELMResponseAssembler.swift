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
    private let timeout: TimeInterval = 1.0

    func clear() {
        buffer.removeAll()
        lastChunkTime = Date()
    }

    func append(_ chunk: String) -> [String] {
        let now = Date()
        if !buffer.isEmpty &&
            now.timeIntervalSince(lastChunkTime) > timeout {

            Logger.shared.info("Assembler Timeout")
            Logger.shared.info("Discarded: \(buffer)")

            buffer.removeAll()
        }

        lastChunkTime = now
        buffer += chunk

        if isComplete(buffer) {
            let response = buffer
            buffer.removeAll()
            return [response]
        }

        return []
    }

    private func isComplete(_ text: String) -> Bool {

        let normalized = text
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalized.hasSuffix(">")
    }
}
