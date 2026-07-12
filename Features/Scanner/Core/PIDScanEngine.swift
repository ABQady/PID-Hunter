//
//  PIDScanEngine.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 09/07/2026.
//
@MainActor
final class PIDScanEngine {

    unowned let scanner: BruteForceScanner

    init(scanner: BruteForceScanner) {
        self.scanner = scanner
    }
}
