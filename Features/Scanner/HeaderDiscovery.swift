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
    
    func discover(probe: String) async -> [HeaderDiscoveryResult] {

        Logger.shared.info("Starting header discovery...")

        var discoveries: [HeaderDiscoveryResult] = []

        for header in candidateHeaders {
            do {
                await ELM327.shared.send("ATSH\(header)")

                let result = try await ELM327.shared.request(
                    command: probe,
                    timeout: .seconds(3)
                )

                switch result.response.type {
                case .positive, .negative:
                    Logger.shared.info("Discovered header: \(header)")
                    Logger.shared.info("Running mode discovery on \(header)...")
                    let modes = await ModeDiscovery.shared.discover(on: header)
                    let modeNames = modes.map { $0.title }.joined(separator: ", ")
                    Logger.shared.info("Header \(header) supports: \(modeNames)")
                    discoveries.append(
                        HeaderDiscoveryResult(
                            header: header,
                            supportedModes: modes
                        )
                    )
                default:
                    break
                }
            } catch BluetoothManager.BluetoothError.timeout {
                continue
            } catch {
                Logger.shared.debug("Header discovery failed for \(header): \(error.localizedDescription)")
            }
        }
        
        if !discoveries.isEmpty {
            await  BikeProfileManager.shared.updateHeaderDiscoveries(discoveries)
        }
        
        Logger.shared.info(
            "💾 Persisted \(discoveries.count) header discoveries."
        )

        Logger.shared.info(
            "Header discovery complete. Found \(discoveries.count) supported headers."
        )
        return discoveries
    }
}
