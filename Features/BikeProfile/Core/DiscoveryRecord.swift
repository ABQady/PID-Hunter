//
//  DiscoveryRecord.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 10/07/2026.
//
import Foundation

enum RecordSource: String, Codable {
    case discovery
    case retryPositive
    case confirmedNegative
}

struct DiscoveryRecord: Hashable, Codable {
    let header: String
    let mode: String
    let request: String
    var response: String
    var firstSeen: Date = .now
    var lastSeen: Date = .now
    var hitCount: Int = 1
    var classification: DiscoveryClassification = .unknown
    var averageLatency: TimeInterval = 0
    var notes: [String] = []
    var source: RecordSource = .discovery
    var hadPartialResponse = false

    enum CodingKeys: String, CodingKey {
        case header
        case mode
        case request
        case response
        case firstSeen
        case lastSeen
        case hitCount
        case classification
        case averageLatency
        case notes
        case source
        case hadPartialResponse
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.header = try container.decode(
            String.self,
            forKey: .header
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        self.mode = try container.decode(
            String.self,
            forKey: .mode
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        self.request = try container.decode(
            String.self,
            forKey: .request
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        self.response = try container.decode(
            String.self,
            forKey: .response
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        self.firstSeen = try container.decodeIfPresent(Date.self, forKey: .firstSeen) ?? .now
        self.lastSeen = try container.decodeIfPresent(Date.self, forKey: .lastSeen) ?? .now
        self.hitCount = try container.decodeIfPresent(Int.self, forKey: .hitCount) ?? 1
        self.classification = try container.decodeIfPresent(DiscoveryClassification.self, forKey: .classification) ?? .unknown
        self.averageLatency = try container.decodeIfPresent(TimeInterval.self, forKey: .averageLatency) ?? 0
        self.notes = try container.decodeIfPresent([String].self, forKey: .notes) ?? []
        self.source = try container.decodeIfPresent(
            RecordSource.self,
            forKey: .source
        ) ?? .discovery
        self.hadPartialResponse = try container.decodeIfPresent(
            Bool.self,
            forKey: .hadPartialResponse
        ) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(header, forKey: .header)
        try container.encode(mode, forKey: .mode)
        try container.encode(request, forKey: .request)
        try container.encode(response, forKey: .response)
        try container.encode(firstSeen, forKey: .firstSeen)
        try container.encode(lastSeen, forKey: .lastSeen)
        try container.encode(hitCount, forKey: .hitCount)
        try container.encode(classification, forKey: .classification)
        try container.encode(averageLatency, forKey: .averageLatency)
        try container.encode(notes, forKey: .notes)
        try container.encode(source, forKey: .source)
        try container.encode(hadPartialResponse, forKey: .hadPartialResponse)
    }

    init(
        header: String,
        mode: String,
        request: String,
        response: String,
        firstSeen: Date = .now,
        lastSeen: Date = .now,
        hitCount: Int = 1,
        classification: DiscoveryClassification = .unknown,
        averageLatency: TimeInterval = 0,
        notes: [String] = [],
        source: RecordSource = .discovery,
        hadPartialResponse: Bool = false
    ) {
        self.header = header.trimmingCharacters(in: .whitespacesAndNewlines)
        self.mode = mode.trimmingCharacters(in: .whitespacesAndNewlines)
        self.request = request.trimmingCharacters(in: .whitespacesAndNewlines)
        self.response = response.trimmingCharacters(in: .whitespacesAndNewlines)
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
        self.hitCount = hitCount
        self.classification = classification
        self.averageLatency = averageLatency
        self.notes = notes
        self.source = source
        self.hadPartialResponse = hadPartialResponse
    }

    var isValid: Bool {
        !header.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !mode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !request.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension DiscoveryRecord {
    @inline(__always)
    private func updatedAverageLatency(
        with latency: TimeInterval
    ) -> TimeInterval {
        (averageLatency * Double(hitCount - 1) + latency) / Double(hitCount)
    }
    mutating func record(response: String, responseType: ELMResponseType, latency: TimeInterval) {
        hitCount += 1
        lastSeen = .now
        self.response = response
        Logger.shared.info("""
📄 Discovery Update
Request        : \(request)
Stored Class   : \(classification)
Incoming Class : \(DiscoveryClassification(from: responseType))
Hit Count      : \(hitCount)
""")
        if !notes.contains(response) {
            notes.append(response)
        }
        averageLatency = updatedAverageLatency(with: latency)
    }
}
