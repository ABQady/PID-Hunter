//
//  SequentialSearchStrategy.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//
struct SequentialSearchStrategy: SearchStrategy {

    let engineType: SearchEngineType = .sequential
    private let start: UInt16
    private let end: UInt16

    private var current: Int

    @inline(__always)
    private var currentPID: UInt16 {
        UInt16(current)
    }

    var isExhausted: Bool {
        current > Int(end)
    }

    // MARK: - Lifecycle
    init(start: UInt16, end: UInt16) {
        precondition(start <= end, "start must not be greater than end")
        self.start = start
        self.end = end
        self.current = Int(start)
    }

    // MARK: - State
    mutating func reset() {
        current = Int(start)
    }

    // MARK: - PID Selection
    mutating func nextPID() -> UInt16? {
        guard current <= Int(end) else {
            return nil
        }
        defer { current += 1 }
        return currentPID
    }

    // MARK: - Learning
    mutating func registerResult(
        pid: UInt16,
        result: SearchResult,
        latency: Double
    ) {
        // Sequential search intentionally ignores scan results.
        _ = pid
        _ = result
        _ = latency
    }
    
    // MARK: - Navigation
    mutating func seek(to pid: UInt16) {
        let clamped = min(
            max(Int(pid), Int(start)),
            Int(end) + 1
        )
        current = clamped
    }

}
