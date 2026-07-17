//
//  PIDScanStrategy.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 09/07/2026.
//

import Foundation

final class PIDScanStrategy: ScanStrategy {

    static let shared = PIDScanStrategy()

    let type: ScanStrategyType = .pid

    private init() {}

    func start(
        mode: OBDMode,
        launcher: ScanLauncher,
        brute: BruteForceScanner,
        context: ScanLauncher.ScanContext
    ) async {

        guard mode.supportsPIDRange else {
            Logger.shared.warning("\(mode.title) does not support PID scanning.")
            return
        }

        Logger.shared.info(
            "PID Strategy → mode=\(mode.rawValue), header=\(context.header)"
        )

        await launcher.startPIDScan(
            brute: brute,
            context: context
        )
    }
}
