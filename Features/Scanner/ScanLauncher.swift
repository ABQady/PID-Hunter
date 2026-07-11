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
        
        let hasResume = ScanPersistence.shared.hasResumePoint

        let metadata = hasResume
            ? ScanPersistence.shared.loadResumeMetadata()
            : nil

        let effectiveHeader = hasResume && !(metadata?.header.isEmpty ?? true)
            ? metadata!.header
            : headerValue

        let effectiveMode = metadata?.mode ?? mode

        let effectiveStartPID = hasResume
            ? String(format: "%04X", metadata!.startPID)
            : startPID

        let effectiveEndPID = hasResume
            ? String(format: "%04X", metadata!.endPID)
            : endPID
        
        let context = ScanContext(
            brute: brute,
            stats: stats,
            header: effectiveHeader,
            startPID: effectiveStartPID,
            endPID: effectiveEndPID
        )
        
        onPrepareUI()
        
        if !hasResume {
            brute.startFresh()
        }
        
        Task { @MainActor in
            guard await prepareSession(header: effectiveHeader) else {
                return
            }

            let strategy = ScanStrategyFactory.strategy(for: effectiveMode)
            Logger.shared.info("Launching \(effectiveMode.rawValue) using \(type(of: strategy))")
            await strategy.start(
                mode: effectiveMode,
                launcher: self,
                context: context
            )
        }
    }
    
    @MainActor
    private func prepareSession(
        header: String
    ) async -> Bool {

        Logger.shared.info("Running preflight using header \(header)")

        let ok = await Preflight.shared.run(header: header)

        guard !Task.isCancelled else {
            return false
        }

        guard ok else {
            Logger.shared.error("❌ Preflight Failed")
            return false
        }

        let fingerprint = ECUInfo.shared.fingerprint

        guard let profile = BikeProfileManager.shared.load(for: fingerprint) else {
            Logger.shared.error("❌ Failed to prepare Bike Profile")
            return false
        }

        Logger.shared.info("🆔 Fingerprint: \(fingerprint.id)")
        Logger.shared.info("📘 Bike Profile Ready")
        Logger.shared.info("Known Requests: \(profile.discoveries.count)")

        return true
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
