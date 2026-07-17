//
//  BikeKnowledgeFilter.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 11/07/2026.
//
@MainActor
struct BikeKnowledgeFilter {
    
    @inline(__always)
    private static func isKnownRequest(
        _ request: String,
        mode: OBDMode,
        header: String,
        profile: BikeProfile
    ) -> Bool {
        profile.discoveries.contains {
            $0.header == header &&
            $0.mode == mode.rawValue &&
            $0.request == request
        }
    }
    
    @inline(__always)
    private static func requestHeader() -> String {
        ECUInfo.shared.header
    }
    
   static func unknownRequests(
        mode: OBDMode,
        from requests: [String],
        profile: BikeProfile?
    ) -> [String] {
        guard let profile else {
            return requests
        }

        let header = requestHeader()

        let shouldScan: (String) -> Bool = {
            !isKnownRequest(
                $0,
                mode: mode,
                header: header,
                profile: profile
            )
        }

        return requests.filter(shouldScan)
    }
    
    static func buildQueue(
        for mode: OBDMode,
        profile: BikeProfile?
    ) -> [String] {
        let pendingRequests = unknownRequests(
            mode: mode,
            from: mode.runtimeRequests,
            profile: profile
        )

        let skippedRequests = mode.runtimeRequests.count - pendingRequests.count

        Logger.shared.info(
            "🧠 Bike Profile skipped \(skippedRequests) known request(s)"
        )

        return pendingRequests
    }
}
