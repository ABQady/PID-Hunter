//
//  BikeKnowledge.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 10/07/2026.
//
import Foundation

struct BikeKnowledge: Codable, Hashable {

    var firstSeen: Date = .now

    var lastSeen: Date = .now

    var hitCount: Int = 1

    var lastResponse: String = ""

    var classification: DiscoveryClassification = .unknown
    
    var averageLatency: TimeInterval = 0

    var notes: [String] = []

}

enum DiscoveryClassification: String, Codable {
    case positive
    case negative
    case noData
    case timeout
    case busError
    case unableToConnect
    case unknown
}

extension DiscoveryClassification {

    init(from responseType: ELMResponseType) {
        switch responseType {
        case .positive:
            self = .positive
        case .negative:
            self = .negative
        case .noData:
            self = .noData
        case .busError:
            self = .busError
        case .unableToConnect:
            self = .unableToConnect
        case .searching,
             .stopped,
             .atResponse,
             .unknown:
            self = .unknown
        }
    }
}

extension BikeKnowledge {

    mutating func record(
        response: String,
        responseType: ELMResponseType,
        latency: TimeInterval
    ) {

        hitCount += 1
        lastSeen = .now
        lastResponse = response
        classification = DiscoveryClassification(from: responseType)
        if !notes.contains(response) {
            notes.append(response)
        }

        averageLatency =
            (averageLatency * Double(hitCount - 1) + latency)
            / Double(hitCount)
    }
}
