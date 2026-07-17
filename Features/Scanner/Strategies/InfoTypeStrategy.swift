//
//  InfoTypeStrategy.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 09/07/2026.
//

import Foundation

final class InfoTypeStrategy: ScanStrategy {

    static let shared = InfoTypeStrategy()

    let type: ScanStrategyType = .infoType

    private init() {}

    func start(
        mode: OBDMode,
        launcher: ScanLauncher,
        brute: BruteForceScanner,
        context: ScanLauncher.ScanContext
    ) async {

        guard mode.scanCapability == .infoType else {
            Logger.shared.error(
                "InfoTypeStrategy cannot handle \(mode.title)"
            )
            return
        }

        guard !mode.discoveryCommand.isEmpty else {
            Logger.shared.error(
                "No discovery command configured for \(mode.title)"
            )
            return
        }

        guard mode.scanCapability == .infoType else {
            Logger.shared.error(
                "Invalid scan capability \(mode.scanCapability) for \(mode.title)"
            )
            return
        }

        Logger.shared.verbose(.setup, "Selected header: \(context.header)")

        Logger.shared.verbose(.setup,
            "Launching Info Type strategy for \(mode.title) using header \(context.header)"
        )

        let requests = mode.runtimeRequests.joined(separator: ", ")
        Logger.shared.verbose(.setup,
            "Runtime requests: \(requests)"
        )

        await launcher.startInfoTypeScan(
            mode: mode,
            brute: brute,
            context: context
        )
    }
}
