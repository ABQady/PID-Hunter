//
//  DiscoveryKey.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 10/07/2026.
//
import Foundation

struct DiscoveryKey: Hashable, Codable {
    let header: String
    let mode: String
    let request: String

    enum CodingKeys: String, CodingKey {
        case header
        case mode
        case request
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.header = try container.decodeIfPresent(
            String.self,
            forKey: .header
        ) ?? ""

        self.mode = try container.decode(
            String.self,
            forKey: .mode
        )

        self.request = try container.decode(
            String.self,
            forKey: .request
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(header, forKey: .header)
        try container.encode(mode, forKey: .mode)
        try container.encode(request, forKey: .request)
    }

    init(header: String, mode: OBDMode, request: String) {
        self.header = header
        self.mode = mode.rawValue
        self.request = request
    }

    init(header: String, mode: String, request: String) {
        self.header = header
        self.mode = mode
        self.request = request
    }

    var isLegacy: Bool {
        header.isEmpty
    }
}
