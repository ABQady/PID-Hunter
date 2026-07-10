//
//  BikeKnowledge.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 10/07/2026.
//
import Foundation

struct BikeKnowledge: Codable {
    var response: String
    var state: DiscoveryState
    var firstSeen: Date
    var lastSeen: Date
    var hitCount: Int
}

enum DiscoveryState: String, Codable {
    case discovered
    case unsupported
    case timeout
    case adapter
    case unknown
}
