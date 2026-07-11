//
//  DiscoveryKey.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 10/07/2026.
//
import Foundation

struct DiscoveryKey: Hashable, Codable {
    let mode: String
    let request: String

    init(mode: OBDMode, request: String) {
        self.mode = mode.rawValue
        self.request = request
    }

    init(mode: String, request: String) {
        self.mode = mode
        self.request = request
    }
}
