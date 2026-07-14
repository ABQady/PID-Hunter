//
//  HeaderDiscovery.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 11/07/2026.
//


import Foundation

struct HeaderDiscoveryResult: Codable, Hashable {
    let header: String
    var supportedModes: [OBDMode]
}

final class HeaderDiscovery {

    static let shared = HeaderDiscovery()

    private let candidateHeaders = [

        "80F111",
        "81F111",
        "82F111",
        "83F111",
        "84F111",
        "85F111",
        "86F111",
        "87F111",
        "88F111",
        "89F111",
        "90F111"

    ]
    
    func discover() async -> [HeaderDiscoveryResult] {

        Logger.shared.info("Starting header discovery...")

        var discoveries: [HeaderDiscoveryResult] = []

        for header in candidateHeaders {
            do {
                try await ELM327.shared.setHeader(header)
            } catch {
                Logger.shared.error("❌ Failed to set header \(header): \(error.localizedDescription)")
                continue
            }

            Logger.shared.info("Running mode discovery on \(header)...")

            let modes = await ModeDiscovery.shared.discover(on: header)

            if !modes.isEmpty {
                let modeNames = modes.map { $0.title }.joined(separator: ", ")
                Logger.shared.info("Discovered header: \(header)")
                Logger.shared.info("Header \(header) supports: \(modeNames)")

                discoveries.append(
                    HeaderDiscoveryResult(
                        header: header,
                        supportedModes: modes
                    )
                )
            }
        }
        
        let uniqueDiscoveries = Dictionary(
            discoveries.map { ($0.header.uppercased(), $0) },
            uniquingKeysWith: { _, newest in newest }
        )
        .values
        .sorted { $0.header < $1.header }

        if !uniqueDiscoveries.isEmpty {
            await BikeProfileManager.shared.updateHeaderDiscoveries(uniqueDiscoveries)

            Logger.shared.info(
                "💾 Persisted \(uniqueDiscoveries.count) header discoveries."
            )
        }

        Logger.shared.info(
            "Header discovery complete. Found \(discoveries.count) supported headers."
        )
        return discoveries
    }
}
