//
//  ProtocolFrameParser.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 14/07/2026.
//

import Foundation

struct ProtocolDefinition: Sendable {

    let headerLength: Int
    let identifierLength: Int
    let hasSequence: Bool
    let hasChecksum: Bool

    @inline(__always)
    func responseService(for requestService: UInt8) -> UInt8 {
        requestService + 0x40
    }

    @inline(__always)
    func identifierLength(for requestService: UInt8) -> Int {
        switch requestService {
        case 0x22:
            return 2

        case 0x01, 0x09, 0x21:
            return 1

        default:
            return identifierLength
        }
    }

    @inline(__always)
    var supportsMultiFrame: Bool {
        hasSequence || hasChecksum
    }

    static let kwp = ProtocolDefinition(
        headerLength: 3,
        identifierLength: 1,
        hasSequence: true,
        hasChecksum: true
    )
}

enum ProtocolFrameParser {

    // MARK: - Public API

    static func parse(
        tokens: [String],
        requestService: UInt8,
        definition: ProtocolDefinition
    ) -> [ProtocolFrame] {
        Logger.shared.info("🧩 Protocol: header=\(definition.headerLength) identifier=\(definition.identifierLength) sequence=\(definition.hasSequence) checksum=\(definition.hasChecksum)")
        let responseService = definition.responseService(for: requestService)
        let identifierLength = definition.identifierLength(for: requestService)

        guard identifierLength > 0 else { return [] }

        var frames: [ProtocolFrame] = []
        var previousSequence: UInt8?
        var cursor = 0

        while let frame = nextFrame(
            in: tokens,
            responseService: responseService,
            definition: definition,
            searchFrom: cursor,
            previousSequence: &previousSequence
        ) {
            frames.append(frame.frame)
            cursor = frame.nextSearchIndex
        }

        if frames.allSatisfy({ $0.sequence != nil }) {
            frames.sort { ($0.sequence ?? 0) < ($1.sequence ?? 0) }
        }

        for frame in frames {
            Logger.shared.info("""
🔎 Protocol Frame
Header     : \(frame.headerHex)
Service    : \(String(format: "%02X", frame.service))
Identifier : \(frame.identifierHex)
Sequence   : \(frame.sequence.map { String(format: "%02X", $0) } ?? "-")
Payload    : \(frame.payloadHex)
Checksum   : \(frame.checksum.map { String(format: "%02X", $0) } ?? "-")
""")
        }

        return frames
    }

    static func assemblePayload(
        from frames: [ProtocolFrame],
        identifier: [UInt8]
    ) -> [UInt8] {
        frames
            .filter { $0.identifier == identifier }
            .flatMap(\.payload)
    }

    // MARK: - Internal

    private struct ParsedFrame {
        let frame: ProtocolFrame
        let nextSearchIndex: Int
    }

    private static func nextFrame(
        in tokens: [String],
        responseService: UInt8,
        definition: ProtocolDefinition,
        searchFrom start: Int,
        previousSequence: inout UInt8?
    ) -> ParsedFrame? {

        let identifierLength = definition.identifierLength

        var serviceIndex = start

        while serviceIndex < tokens.count {
            guard let value = UInt8(tokens[serviceIndex], radix: 16),
                  value == responseService else {
                serviceIndex += 1
                continue
            }

            guard serviceIndex + identifierLength < tokens.count else {
                return nil
            }

            let headerStart = max(0, serviceIndex - definition.headerLength)
            let header = tokens[headerStart..<serviceIndex].compactMap { UInt8($0, radix: 16) }

            let identifier = tokens[(serviceIndex + 1)...(serviceIndex + identifierLength)]
                .compactMap { UInt8($0, radix: 16) }

            var cursor = serviceIndex + 1 + identifierLength

            var sequence: UInt8?
            if definition.hasSequence {
                if cursor < tokens.count,
                   let seq = UInt8(tokens[cursor], radix: 16) {
                    if previousSequence == nil, seq == 0x01 {
                        sequence = seq
                        previousSequence = seq
                        cursor += 1
                    } else if let lastSequence = previousSequence,
                              seq == lastSequence &+ 1 {
                        sequence = seq
                        previousSequence = seq
                        cursor += 1
                    }
                }
            }

            var payload: [UInt8] = []
            var checksum: UInt8?
            var scan = cursor

            while scan < tokens.count {
                if let value = UInt8(tokens[scan], radix: 16),
                   value == responseService,
                   scan + identifierLength < tokens.count {

                    if definition.hasChecksum {
                        if scan > cursor,
                           let chk = UInt8(tokens[scan - 1], radix: 16) {
                            checksum = chk
                            payload.removeLast()
                        }
                    }

                    break
                }

                if let byte = UInt8(tokens[scan], radix: 16) {
                    payload.append(byte)
                }

                scan += 1
            }

            return ParsedFrame(
                frame: ProtocolFrame(
                    header: header,
                    service: responseService,
                    identifier: identifier,
                    sequence: sequence,
                    payload: payload,
                    checksum: checksum
                ),
                nextSearchIndex: scan
            )
        }

        return nil
    }
}
