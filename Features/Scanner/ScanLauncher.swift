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
    
    func start(
        bt: BluetoothManager,
        brute: BruteForceScanner,
        stats: ScanStatistics,
        mode: OBDMode,
        header: String,
        startPID: String,
        endPID: String,
        cleanHeader: String,
        onPrepareUI: @escaping () -> Void
    ){
        guard bt.isConnected else {
            Logger.shared.info("Connect to ELM first")
            return
        }
        if !brute.hasResumePoint {
            Logger.shared.clear()
        }
        
        let headerValue = cleanHeader
        
        guard headerValue.count == 6,
              headerValue.allSatisfy({ $0.isHexDigit }) else {
            Logger.shared.info("Invalid Header")
            return
        }
        brute.headers = [headerValue]
        onPrepareUI()
        
        if !brute.hasResumePoint {
            brute.startFresh()
        }
        
        Task {
            let ok = await Preflight.shared.run(header: headerValue)
            
            guard !Task.isCancelled else { return }
            
            guard ok else {
                Logger.shared.error("❌ Preflight Failed")
                return
            }
            
            if mode.pidDigits == 4 {
                let startText = startPID
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .uppercased()
                
                let endText = endPID
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
                brute.scan(
                    mode: mode,
                    startPID: start,
                    endPID: end
                )
            } else {
                guard !Task.isCancelled else { return }
                brute.scan(mode: mode)
            }
        }
    }
    
}
