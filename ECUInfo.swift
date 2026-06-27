//
//  ECUInfo.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 27/06/2026.
//
import Foundation

struct SupportedServices {

    var services: [String] = []
}

@MainActor
final class ECUInfo: ObservableObject {

    static let shared = ECUInfo()

    @Published var ecuName = "Unknown"
    @Published var elmVersion = "-"
    @Published var protocolName = "-"
    @Published var header = "-"
    @Published var status = "-"
    @Published var services = SupportedServices()
    @Published var lastConnected: Date?

    private init() {}

    func clear() {
        ecuName = "Unknown"
        elmVersion = "-"
        protocolName = "-"
        header = "-"
        status = "-"
        services = SupportedServices()
        lastConnected = nil
    }
    
    func addService(_ service: UInt8?) {

        guard let service else {
            return
        }

        let value = String(format: "%02X", service)

        guard !services.services.contains(value) else {
            return
        }

        services.services.append(value)
        services.services.sort()
    }
}
