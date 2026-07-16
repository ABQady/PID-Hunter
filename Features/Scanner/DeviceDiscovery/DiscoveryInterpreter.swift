//
//  DiscoveryInterpreter.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 16/07/2026.
//

import Foundation

/// Translates low-level transport responses into semantic device discovery decisions.
/// This layer is the single source of truth for all Device Discovery logic.
protocol DiscoveryInterpreter {

    func interpret(
        requestAddress: UInt8,
        response: ELMResponse
    ) -> DiscoveryResult
}

enum DiscoveryResult: Equatable {

    case ecuFound(ECUDiscovery)

    case unsupportedAddress

    case ignored(DiscoveryIgnoreReason)

    case invalidResponse(DiscoveryFailureReason)

    case transportError(TransportFailureReason)
}

struct ECUDiscovery: Equatable {

    let requestAddress: UInt8

    let respondingAddress: UInt8

    let response: ELMResponse

    let confidence: Float

    let reason: DiscoveryReason
}

enum DiscoveryReason: Codable, Equatable {

    case positiveResponse

    case negativeResponse

    case startCommunication

    case protocolHandshake
}

enum DiscoveryIgnoreReason: Equatable {

    case unrelatedFrame

    case incompleteFrame

    case duplicateFrame
}

enum DiscoveryFailureReason: Equatable {

    case malformedFrame

    case unsupportedProtocol

    case unsupportedService

    case missingHeader

    case parserRejected

    case missingResponseAddress

    case invalidAddressMapping
}

enum TransportFailureReason: Equatable {

    case timeout

    case connectionLost

    case cancelled

    case transportError
}
