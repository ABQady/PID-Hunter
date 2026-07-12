//
//  FixedCommandStrategy.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 09/07/2026.
//

import Foundation

final class FixedCommandStrategy: ScanStrategy {

    static let shared = FixedCommandStrategy()

    let type: ScanStrategyType = .fixedCommand

    private init() {}

    func start(
        mode: OBDMode,
        launcher: ScanLauncher,
        context: ScanLauncher.ScanContext
    ) async {

        guard mode.scanCapability == .fixedCommand else {
            Logger.shared.error(
                "FixedCommandStrategy cannot handle \(mode.title)"
            )
            return
        }

        guard !mode.discoveryCommand.isEmpty else {
            Logger.shared.error(
                "No discovery command configured for \(mode.title)"
            )
            return
        }

        guard mode.requestFormat == .singleCommand else {
            Logger.shared.error(
                "Invalid request format \(mode.requestFormat) for \(mode.title)"
            )
            return
        }

        Logger.shared.info(
            "Launching Fixed Command strategy for \(mode.title) using header \(context.header)"
        )

        let requests = mode.runtimeRequests.joined(separator: ", ")
        Logger.shared.debug(
            "Runtime requests: \(requests)"
        )

        await launcher.startFixedCommandScan(
            mode: mode,
            context: context
        )
    }
}
