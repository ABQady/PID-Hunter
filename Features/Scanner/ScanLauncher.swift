//
//  ScanLauncher.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 04/07/2026.
//
import Foundation

@MainActor
final class ScanLauncher {

    static let shared = ScanLauncher()

    private init() {}
    
    struct ScanContext {
        let brute: BruteForceScanner
        let stats: ScanStatistics
        let header: String
        let startPID: String
        let endPID: String
    }
    
    func startFixedCommandScan(
        mode: OBDMode,
        context: ScanContext
    ) async {
        await context.brute.scanFixedCommands(
            mode: mode,
            context: context
        )
    }

    func startInfoTypeScan(
        mode: OBDMode,
        context: ScanContext
    ) async {
        await context.brute.scanInfoType(
            mode: mode,
            context: context
        )
    }
    
    func start(
        bt: BluetoothManager,
        brute: BruteForceScanner,
        stats: ScanStatistics,
        mode: OBDMode,
        startPID: String,
        endPID: String,
        cleanHeader: String,
        onPrepareUI: @escaping () -> Void
    ){
        guard bt.isConnected else {
            Logger.shared.info("Connect to ELM first")
            return
        }
        if !ScanPersistence.shared.hasResumePoint {
            Logger.shared.clear()
        }
        
        let headerValue = cleanHeader
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        
        guard headerValue.count == 6,
              headerValue.allSatisfy({ $0.isHexDigit }) else {
            Logger.shared.error("Invalid header: \(headerValue)")
            return
        }
        
        let context = ScanContext(
            brute: brute,
            stats: stats,
            header: headerValue,
            startPID: startPID,
            endPID: endPID
        )
        
        onPrepareUI()
        
        if !ScanPersistence.shared.hasResumePoint {
            brute.startFresh()
        }
        
        Task {
            Logger.shared.info("Running preflight using header \(headerValue)")
            let ok = await Preflight.shared.run(header: headerValue)
            
            guard !Task.isCancelled else { return }
            
            guard ok else {
                Logger.shared.error("❌ Preflight Failed")
                return
            }
            
            let strategy = ScanStrategyFactory.strategy(for: mode)
            Logger.shared.info("Launching \(mode.rawValue) using \(type(of: strategy))")
            await strategy.start(
                mode: mode,
                launcher: self,
                context: context
            )
        }
    }
    
    func startPIDScan(
        mode: OBDMode,
        context: ScanContext,
    ) async {

        switch mode.scanCapability {

        case .pid8:
            guard !Task.isCancelled else { return }
            context.brute.scan(
                mode: mode,
                header: context.header
            )

        case .pid16:
            let startText = context.startPID
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()

            let endText = context.endPID
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()

            guard let start = UInt16(startText, radix: 16),
                  let end = UInt16(endText, radix: 16) else {
                Logger.shared.info("Invalid PID range")
                return
            }

            guard start <= end else {
                Logger.shared.info("Start PID must be <= End PID")
                return
            }

            guard !Task.isCancelled else { return }
            
            context.brute.scan(
                mode: mode,
                header: context.header,
                startPID: start,
                endPID: end
            )
        case .fixedCommand:
            assertionFailure("FixedCommandStrategy must call startFixedCommandScan().")

        case .infoType:
            assertionFailure("InfoTypeStrategy must call startInfoTypeScan().")
        }
    }
    
}
