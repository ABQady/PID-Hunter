//
//  BikeKnowledgeFilter.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 11/07/2026.
//
struct BikeKnowledgeFilter {
    
   static func unknownRequests(
        mode: OBDMode,
        from requests: [String],
        profile: BikeProfile?
    ) -> [String] {
        guard let profile else {
            return requests
        }

        let header = profile.fingerprint.header

        return requests.filter { request in
            return !profile.discoveries.contains { record in
                record.header == header &&
                record.mode == mode.rawValue &&
                record.request == request
            }
        }
    }
    
    static func buildQueue(
        for mode: OBDMode,
        profile: BikeProfile?
    ) -> [String] {
        let queue = unknownRequests(
            mode: mode,
            from: mode.runtimeRequests,
            profile: profile
        )

    Logger.shared.info(
            "🧠 Bike Profile filtered \(mode.runtimeRequests.count - queue.count) known request(s)"
        )

        return queue
    }
}
