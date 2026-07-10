//
//  ScanStrategy.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 09/07/2026.
//

import Foundation


/// Strategy responsible for executing a scan for a specific family of OBD services.
/// The launcher performs orchestration and dependency injection, while each strategy
/// owns only the execution algorithm.
protocol ScanStrategy: AnyObject {

    func start(
        mode: OBDMode,
        launcher: ScanLauncher,
        context: ScanLauncher.ScanContext
    ) async
}

/// Central factory responsible for resolving the runtime scan strategy for an OBD mode.
/// Adding a new ScanStrategyType should require updating this switch.
enum ScanStrategyFactory {

    @inline(__always)
    static func strategy(for mode: OBDMode) -> any ScanStrategy {

        switch mode.scanStrategy {

        case .pid:
            return PIDScanStrategy.shared

        case .fixedCommand:
            return FixedCommandStrategy.shared

        case .infoType:
            return InfoTypeStrategy.shared
        }
    }
}
