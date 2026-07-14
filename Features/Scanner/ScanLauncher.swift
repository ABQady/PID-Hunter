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
        let mode: OBDMode
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
    
    private func resolveScanContext(
        mode: OBDMode,
        header: String,
        startPID: String,
        endPID: String,
        brute: BruteForceScanner,
        stats: ScanStatistics
    ) -> ScanContext {
        let hasResume = ScanPersistence.shared.hasResumePoint
        let metadata = hasResume ? ScanPersistence.shared.loadResumeMetadata() : nil

        let effectiveHeader = hasResume && !(metadata?.header.isEmpty ?? true)
            ? metadata!.header
            : header

        let effectiveMode = metadata?.mode ?? mode

        let effectiveStartPID = hasResume
            ? String(format: "%04X", metadata!.startPID)
            : startPID

        let effectiveEndPID = hasResume
            ? String(format: "%04X", metadata!.endPID)
            : endPID

        return ScanContext(
            brute: brute,
            stats: stats,
            mode: effectiveMode,
            header: effectiveHeader,
            startPID: effectiveStartPID,
            endPID: effectiveEndPID
        )
    }

    // MARK: - Scan Launch
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
        
        let context = resolveScanContext(
            mode: mode,
            header: headerValue,
            startPID: startPID,
            endPID: endPID,
            brute: brute,
            stats: stats
        )

        let hasResume = ScanPersistence.shared.hasResumePoint

        // Build logging metadata
        let loggingMetadata = LogSessionManager.Metadata(
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            mode: context.mode,
            header: context.header,
            searchEngine: brute.searchEngine,
            requestDelay: brute.delayMs / 1000.0,
            requestTimeout: UserDefaults.standard.double(forKey: "requestTimeout"),
            autoPreflight: UserDefaults.standard.bool(forKey: "enableAutoPreflight"),
            debugLogging: UserDefaults.standard.bool(forKey: "enableDebugLogging")
        )

        onPrepareUI()

        if !hasResume {
            brute.startFresh()
        }

        Task { @MainActor in
            // MARK: - PreScan Session
            guard await prepareSession(
                context: context,
                loggingMetadata: loggingMetadata
            ) else {
                return
            }
            do {
                try await LogSessionManager.shared.startScanSession(
                    mode: context.mode,
                    header: context.header,
                    searchEngine: brute.searchEngine,
                    logger: Logger.shared
                )
                // From this point onward, every log entry belongs to the dedicated scan log.
            } catch {
                Logger.shared.error(
                    "Failed to promote log session: \(error)"
                )
                return
            }

            // Strategy creation intentionally happens after session promotion so that
            // strategy initialization logs never leak into the PreScan log.
            let strategy = ScanStrategyFactory.strategy(for: context.mode)
            Logger.shared.info("Launching \(context.mode.rawValue) using \(type(of: strategy))")
            await strategy.start(
                mode: context.mode,
                launcher: self,
                context: context
            )

            // The scan log has finished. Start collecting post-scan activity.
            do {
                try await LogSessionManager.shared.closeCurrentLog(
                    logger: Logger.shared
                )

                try await LogSessionManager.shared.startPreScanSession(
                    logger: Logger.shared
                )
            } catch {
                Logger.shared.error("Failed to restore PreScan session: \(error)")
                assertionFailure("Failed to restore PreScan session")
            }
        }
    }
    
    @MainActor
    private func prepareSession(
        context: ScanContext,
        loggingMetadata: LogSessionManager.Metadata
    ) async -> Bool {

        // Begin logging session with metadata
        do {
            try await LogSessionManager.shared.startInitialPreScanSessionIfNeeded(
                metadata: loggingMetadata,
                logger: Logger.shared
            )
        } catch {
            Logger.shared.error("❌ Failed to start logging session: \(error)")
            return false
        }

        Logger.shared.info("Running preflight using header \(context.header)")

        let ok = await Preflight.shared.run(
            header: context.header,
            mode: context.mode
        )

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
            await context.brute.scan(
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
            
            await context.brute.scan(
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
