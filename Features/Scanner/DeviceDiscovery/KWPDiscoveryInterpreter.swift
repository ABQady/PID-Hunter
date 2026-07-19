//
//  KWPDiscoveryInterpreter.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 16/07/2026.
//

import Foundation

final class KWPDiscoveryInterpreter: DiscoveryInterpreter {

    func interpret(
        requestAddress: UInt8,
        response: ELMResponse
    ) -> DiscoveryResult {

        switch response.type {
        case .positive:
            guard let respondingAddress = response.respondingAddress else {
                return .invalidResponse(.missingResponseAddress)
            }
            return interpretPositive(
                requestAddress: requestAddress,
                respondingAddress: respondingAddress,
                response: response
            )

        case .negative:
            return interpretNegative(
                requestAddress: requestAddress,
                response: response
            )

        case .unknown:
            return interpretUnknown()

        case .partialFrame:
            return .ignored(.incompleteFrame)

        case .noData:
            return .unsupportedAddress

        case .stopped,
             .busError,
             .unableToConnect:
            return .transportError(.timeout)

        case .searching,
             .atResponse:
            return .ignored(.unrelatedFrame)
        }
    }

    private func interpretPositive(
        requestAddress: UInt8,
        respondingAddress: UInt8,
        response: ELMResponse
    ) -> DiscoveryResult {

        let reason: DiscoveryReason

        switch response.service {
        case 0x81:
            reason = .startCommunication

        default:
            reason = .positiveResponse
        }

        return .ecuFound(
            ECUDiscovery(
                requestAddress: requestAddress,
                respondingAddress: respondingAddress,
                response: response,
                confidence: calculateConfidence(for: reason),
                reason: reason
            )
        )
    }

    private func interpretNegative(
        requestAddress: UInt8,
        response: ELMResponse
    ) -> DiscoveryResult {

        guard let respondingAddress = response.respondingAddress else {
            return .invalidResponse(.missingResponseAddress)
        }

        return .ecuFound(
            ECUDiscovery(
                requestAddress: requestAddress,
                respondingAddress: respondingAddress,
                response: response,
                confidence: calculateConfidence(for: .negativeResponse),
                reason: .negativeResponse
            )
        )
    }

    private func interpretUnknown() -> DiscoveryResult {
        .ignored(.unrelatedFrame)
    }

    private func calculateConfidence(for reason: DiscoveryReason) -> Float {
        switch reason {
        case .positiveResponse:
            return 1.0
        case .startCommunication:
            return 1.0
        case .negativeResponse:
            return 0.8
        case .protocolHandshake:
            return 0.9
        }
    }
}
