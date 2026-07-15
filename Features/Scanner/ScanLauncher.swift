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
    private typealias ResumeMetadata = ScanPersistence.ResumeMetadata

    private init() {}
    
    struct ScanContext {
        let mode: OBDMode
        let header: String
        let startPID: UInt16
        let endPID: UInt16
        let resumeMetadata: ScanPersistence.ResumeMetadata?
        let resumeResults: [ScanResult]
    }
    
    func startFixedCommandScan(
        mode: OBDMode,
        brute: BruteForceScanner,
        context: ScanContext
    ) async {
        await brute.scanFixedCommands(
            mode: mode,
            context: context
        )
    }

    func startInfoTypeScan(
        mode: OBDMode,
        brute: BruteForceScanner,
        context: ScanContext
    ) async {
        await brute.scanInfoType(
            mode: mode,
            context: context
        )
    }
    
    /// Builds the immutable ScanContext from already-resolved launch state.
    /// It must not read global runtime state or persistence.
    private func resolveScanContext(
        mode: OBDMode,
        header: String,
        startPID: String,
        endPID: String,
        resumeMetadata: ResumeMetadata?,
        resumeResults: [ScanResult]
    ) -> ScanContext {
        let effectiveHeader: String
        if let resumeMetadata,
           !resumeMetadata.header.isEmpty {
            effectiveHeader = resumeMetadata.header
        } else {
            effectiveHeader = header
        }

        let effectiveMode = resumeMetadata?.mode ?? mode

        let effectiveStartPID: UInt16
        let effectiveEndPID: UInt16
        if let resumeMetadata = resumeMetadata {
            guard let start = UInt16(exactly: resumeMetadata.startPID),
                  let end = UInt16(exactly: resumeMetadata.endPID) else {
                preconditionFailure("Resume metadata contains invalid PID range")
            }
            effectiveStartPID = start
            effectiveEndPID = end
        } else {
            guard let start = UInt16(startPID, radix: 16),
                  let end = UInt16(endPID, radix: 16) else {
                preconditionFailure("Invalid PID range after launch validation")
            }
            effectiveStartPID = start
            effectiveEndPID = end
        }

        return ScanContext(
            mode: effectiveMode,
            header: effectiveHeader,
            startPID: effectiveStartPID,
            endPID: effectiveEndPID,
            resumeMetadata: resumeMetadata,
            resumeResults: resumeResults
        )
    }
    
    // MARK: - Settings
    private func isAutoPreflightEnabled() -> Bool {
        let defaults = UserDefaults.standard

        guard defaults.object(forKey: "enableAutoPreflight") != nil else {
            return true
        }

        return defaults.bool(forKey: "enableAutoPreflight")
    }

    // MARK: - Launch Preparation
    private func prepareFreshScan(brute: BruteForceScanner) {
        Logger.shared.info("🧹 Preparing fresh scan session")

        brute.startFresh()

        ScanPersistence.shared.clearResumePoint(
            session: brute.session
        )    }
    
    // MARK: - Resume Resolution
    private func resolveResumeState() -> (
        hasResume: Bool,
        metadata: ResumeMetadata?,
        results: [ScanResult]
    ) {
        let hasResume = ScanPersistence.shared.hasResumePoint
        let metadata = hasResume ? ScanPersistence.shared.loadResumeMetadata() : nil
        let results = hasResume ? ScanPersistence.shared.loadResults() : []
        return (
            hasResume: hasResume,
            metadata: metadata,
            results: results
        )
    }

    // MARK: - Launch Preparation
    private func prepareScan(
        mode: OBDMode,
        startPID: String,
        endPID: String,
        cleanHeader: String,
        brute: BruteForceScanner
    ) -> ScanContext? {
        let headerValue = cleanHeader
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard headerValue.count == 6,
              headerValue.allSatisfy({ $0.isHexDigit }) else {
            Logger.shared.error("Invalid header: \(headerValue)")
            return nil
        }

        let startPIDNormalized = startPID
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        let endPIDNormalized = endPID
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard let startPIDValue = UInt16(startPIDNormalized, radix: 16),
              let endPIDValue = UInt16(endPIDNormalized, radix: 16),
              startPIDValue <= endPIDValue else {
            Logger.shared.error("Invalid PID range")
            return nil
        }

        // Read resume state exactly once using helper
        let resume = resolveResumeState()

        prepareLaunchState(
            hasResume: resume.hasResume,
            brute: brute
        )

        let context = resolveScanContext(
            mode: mode,
            header: headerValue,
            startPID: startPIDNormalized,
            endPID: endPIDNormalized,
            resumeMetadata: resume.metadata,
            resumeResults: resume.results
        )

        Logger.shared.info("Resume Results: \(resume.results.count)")

        logLaunchContext(context, hasResume: resume.hasResume)

        return context
    }

    // MARK: - Launch State
    private func prepareLaunchState(
        hasResume: Bool,
        brute: BruteForceScanner
    ) {
        if hasResume {
            return
        }

        Logger.shared.clear()
        prepareFreshScan(brute: brute)
    }

    // MARK: - Launch Logging
    private func logLaunchContext(
        _ context: ScanContext,
        hasResume: Bool
    ) {
        Logger.shared.info("""
🚀 Scan Context
Resume    : \(hasResume)
Mode      : \(context.mode.rawValue)
Header    : \(context.header)
Start PID : \(context.startPID)
End PID   : \(context.endPID)
""")
    }

    // MARK: - Scan Launch
    func start(
        bt: BluetoothManager,
        brute: BruteForceScanner,
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
        
        guard let context = prepareScan(
            mode: mode,
            startPID: startPID,
            endPID: endPID,
            cleanHeader: cleanHeader,
            brute: brute
        ) else {
            return
        }
        
        onPrepareUI()

        Task { @MainActor in
            guard await prepareSession(
                context: context,
                brute: brute
            ) else {
                return
            }
            guard await promoteScanLog(context: context, brute: brute) else {
                return
            }
            await runStrategy(brute: brute, context: context)
            await restorePreScanLog()
        }
    }
    
    // MARK: - Scan Session Preparation
    @MainActor
    private func prepareSession(
        context: ScanContext,
        brute: BruteForceScanner
    ) async -> Bool {
        guard await prepareLoggingSession(context: context, brute: brute) else { return false }
        guard await runPreflight(context) else { return false }
        guard prepareBikeProfile() else { return false }
        return true
    }

    // MARK: - Logging Preparation
    private func prepareLoggingSession(
        context: ScanContext,
        brute: BruteForceScanner
    ) async -> Bool {
        do {
            try await LogSessionManager.shared.startInitialPreScanSessionIfNeeded(
                logger: Logger.shared
            )
        } catch {
            Logger.shared.error("❌ Failed to start logging session: \(error)")
            return false
        }
        return true
    }

    // MARK: - ECU Preparation
    private func runPreflight(
        _ context: ScanContext
    ) async -> Bool {
        guard isAutoPreflightEnabled() else {
            Logger.shared.info("⏭️ Auto Preflight Disabled")
            return true
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
        return true
    }

    // MARK: - Bike Profile Preparation
    private func prepareBikeProfile() -> Bool {
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
    
    // MARK: - Scan Log Lifecycle
    private func promoteScanLog(
        context: ScanContext,
        brute: BruteForceScanner
    ) async -> Bool {
        do {
            try await LogSessionManager.shared.startScanSession(
                mode: context.mode,
                header: context.header,
                searchEngine: brute.searchEngine,
                requestDelay: brute.delayMs / 1000.0,
                logger: Logger.shared
            )
            // From this point onward, every log entry belongs to the dedicated scan log.
        } catch {
            Logger.shared.error(
                "Failed to promote log session: \(error)"
            )
            return false
        }
        return true
    }

    private func restorePreScanLog() async {
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

    // MARK: - Strategy Execution
    private func runStrategy(
        brute: BruteForceScanner,
        context: ScanContext
    ) async {
        let strategy = ScanStrategyFactory.strategy(for: context.mode)
        Logger.shared.info("Launching \(context.mode.rawValue) using \(type(of: strategy))")
        await strategy.start(
            mode: context.mode,
            launcher: self,
            brute: brute,
            context: context
        )
    }
    
    
    // MARK: - Strategy Dispatch
    func startPIDScan(
        brute: BruteForceScanner,
        context: ScanContext
    ) async {
        guard !Task.isCancelled else { return }
        await brute.scan(context: context)
    }
    
    
}
