//
//  DiscoveryModels.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 16/07/2026.
//


import Foundation

struct DeviceDiscoveryRecord: Codable, Equatable, Identifiable, Hashable {
    var id = UUID()

    let requestAddress: UInt8

    let respondingAddress: UInt8

    let response: ELMResponse

    let latency: TimeInterval

    let confidence: Float

    let reason: DiscoveryReason

    let timestamp: Date
}

struct DiscoverySession: Equatable {

    var records: [DeviceDiscoveryRecord] = []

    var successfulRecords: [DeviceDiscoveryRecord] {
        records.filter { $0.confidence > 0 }
    }

    var respondingAddresses: [UInt8] {
        Array(Set(successfulRecords.map(\.respondingAddress))).sorted()
    }
}
