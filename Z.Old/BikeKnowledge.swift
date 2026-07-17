////
////  BikeKnowledge.swift
////  PID Hunter
////
////  Created by Ahmed Al Qady on 10/07/2026.
////
//import Foundation
//import SwiftUI
//
//struct BikeKnowledge: Codable, Hashable {
//
//    var firstSeen: Date = .now
//
//    var lastSeen: Date = .now
//
//    var hitCount: Int = 1
//
//    var lastResponse: String = ""
//
//    var classification: DiscoveryClassification = .unknown
//    
//    var averageLatency: TimeInterval = 0
//
//    var notes: [String] = []
//
//}
//
//enum DiscoveryClassification: String, Codable {
//    case positive
//    case negative
//    case noData
//    case timeout
//    case busError
//    case unableToConnect
//    case unknown
//}
//
//extension DiscoveryClassification {
//
//    init(from responseType: ELMResponseType) {
//        switch responseType {
//        case .positive:
//            self = .positive
//        case .negative:
//            self = .negative
//        case .noData:
//            self = .noData
//        case .busError:
//            self = .busError
//        case .unableToConnect:
//            self = .unableToConnect
//        case .searching,
//             .stopped,
//             .atResponse,
//             .unknown:
//            self = .unknown
//        }
//    }
//}
//
//extension DiscoveryClassification {
//
//    var title: String {
//        switch self {
//        case .positive: "Positive"
//        case .negative: "Negative"
//        case .noData: "No Data"
//        case .timeout: "Timeout"
//        case .unknown: "Unknown"
//        case .busError: "Bus Error"
//        case .unableToConnect: "Unable to Conect"
//        }
//    }
//
//    var icon: String {
//        switch self {
//        case .positive: "checkmark.circle.fill"
//        case .negative: "xmark.circle.fill"
//        case .noData: "minus.circle.fill"
//        case .timeout: "clock.badge.xmark.fill"
//        case .unknown: "questionmark.circle.fill"
//        case .busError:" xmark.circle.fill"
//        case .unableToConnect: "xmark.circle.fill"
//        }
//    }
//
//    var color: Color {
//        switch self {
//        case .positive: .green
//        case .negative: .red
//        case .noData: .orange
//        case .timeout: .yellow
//        case .unknown: .gray
//        case .busError: .red
//        case .unableToConnect: .red
//        }
//    }
//
//}
//extension DiscoveryClassification: Identifiable {
//    public var id: Self { self }
//}
//extension BikeKnowledge {
//
//    mutating func record(
//        response: String,
//        responseType: ELMResponseType,
//        latency: TimeInterval
//    ) {
//
//        hitCount += 1
//        lastSeen = .now
//        lastResponse = response
//        classification = DiscoveryClassification(from: responseType)
//        if !notes.contains(response) {
//            notes.append(response)
//        }
//
//        averageLatency =
//            (averageLatency * Double(hitCount - 1) + latency)
//            / Double(hitCount)
//    }
//}
