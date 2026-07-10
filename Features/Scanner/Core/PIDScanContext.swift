//
//  PIDScanContext.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 09/07/2026.
//
struct PIDScanContext {
    let configuration: ScanConfiguration
    let session: ScanSession
    let persistence: ScanPersistence
    let statistics: SearchStatistics
    let stats: ScanStatistics
    let requestExecutor: RequestExecutor
    let scanStatus: ScanStatus
    let searchEngine: SearchEngineType
    let requestTimeout: Double
    let maxConsecutiveTimeouts: Int
    var shouldStop = false
}
