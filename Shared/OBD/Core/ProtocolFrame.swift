//
//  ProtocolFrame.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 14/07/2026.
//

import Foundation

/// Represents a single protocol frame extracted from the transport stream.
///
/// A ProtocolFrame is transport-level data only. It intentionally contains no
/// application-specific knowledge about OBD services or PID semantics.
struct ProtocolFrame: Sendable, Hashable {

    /// Transport header (if present).
    let header: [UInt8]

    /// Positive response service byte (e.g. 0x41, 0x49, 0x62...).
    let service: UInt8

    /// Service identifier bytes (PID, DID, InfoType... depending on protocol).
    let identifier: [UInt8]

    /// Optional transport sequence number.
    let sequence: UInt8?

    /// Application payload contained by this frame.
    let payload: [UInt8]

    /// Optional transport checksum when structurally identified.
    let checksum: UInt8?

    @inline(__always)
    var hasSequence: Bool {
        sequence != nil
    }

    @inline(__always)
    var hasHeader: Bool {
        !header.isEmpty
    }

    @inline(__always)
    var hasChecksum: Bool {
        checksum != nil
    }

    @inline(__always)
    private func hexString(_ bytes: [UInt8], separator: String = " ") -> String {
        bytes
            .map { String(format: "%02X", $0) }
            .joined(separator: separator)
    }

    @inline(__always)
    var identifierHex: String {
        hexString(identifier, separator: "")
    }

    @inline(__always)
    var payloadHex: String {
        hexString(payload, separator: " ")
    }

    @inline(__always)
    var headerHex: String {
        hexString(header, separator: " ")
    }

    @inline(__always)
    var serviceHex: String {
        String(format: "%02X", service)
    }

    @inline(__always)
    var sequenceHex: String {
        guard let sequence else { return "-" }
        return String(format: "%02X", sequence)
    }

    @inline(__always)
    var checksumHex: String {
        guard let checksum else { return "-" }
        return String(format: "%02X", checksum)
    }

    @inline(__always)
    var debugDescription: String {
        """
        Header     : \(headerHex)
        Service    : \(serviceHex)
        Identifier : \(identifierHex)
        Sequence   : \(sequenceHex)
        Payload    : \(payloadHex)
        Checksum   : \(checksumHex)
        """
    }
}
