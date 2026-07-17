//
//  ScanSession.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 12/07/2026.
//
import Foundation

@MainActor

final class ScanSession {
    var results: [ScanResult] = []
    var seen = Set<String>()
    var currentPID = 0
    // Resume Session metadata

    var header = ""
    var mode: OBDMode?
    var startPID = 0
    var endPID = 0
    var searchStrategy: any SearchStrategy =

        SequentialSearchStrategy(start: 0, end: 0)
}
