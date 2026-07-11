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

        Logger.shared.info("Selected header: \(context.header)")

        Logger.shared.info(
            "Launching Info Type strategy for \(mode.title) using header \(context.header)"
        )

        let requests = mode.runtimeRequests.joined(separator: ", ")
        Logger.shared.debug(
            "Runtime requests: \(requests)"
        )

        await launcher.startInfoTypeScan(
            mode: mode,
            context: context
        )
    }
}
