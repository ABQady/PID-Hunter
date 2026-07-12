//
//  DiscoveryClassification.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 12/07/2026.
//
import Foundation
import SwiftUI

enum DiscoveryClassification: String, Codable {
    case positive
    case negative
    case noData
    case timeout
    case busError
    case unableToConnect
    case unknown
    case partialFrame
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
        case .partialFrame:
            self = .partialFrame
        }
    }
}

extension DiscoveryClassification {

    var title: String {
        switch self {
        case .positive: "Positive"
        case .negative: "Negative"
        case .noData: "No Data"
        case .timeout: "Timeout"
        case .unknown: "Unknown"
        case .busError: "Bus Error"
        case .unableToConnect: "Unable to Connect"
        case .partialFrame: "Partial Frame"
        }
    }

    var icon: String {
        switch self {
        case .positive: "checkmark.circle.fill"
        case .negative: "xmark.circle.fill"
        case .noData: "minus.circle.fill"
        case .timeout: "clock.badge.xmark.fill"
        case .unknown: "questionmark.circle.fill"
        case .busError: "xmark.circle.fill"
        case .unableToConnect: "xmark.circle.fill"
        case .partialFrame: "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .positive: .green
        case .negative: .red
        case .noData: .orange
        case .timeout: .yellow
        case .unknown: .gray
        case .busError: .red
        case .unableToConnect: .red
        case .partialFrame: .yellow
        }
    }

}
extension DiscoveryClassification: Identifiable {
    public var id: Self { self }
}
