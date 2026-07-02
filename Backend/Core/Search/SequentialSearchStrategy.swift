//
//  SequentialSearchStrategy.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//
struct SequentialSearchStrategy: SearchStrategy {

    private let start: UInt16
    private let end: UInt16

    private var current: Int

    init(start: UInt16, end: UInt16) {
        precondition(start <= end, "start must not be greater than end")
        self.start = start
        self.end = end
        self.current = Int(start)
    }

    mutating func reset() {
        current = Int(start)
    }

    // MARK: - PID Selection
    mutating func nextPID() -> UInt16? {

        guard current <= Int(end) else {
            return nil
        }

        let pid = UInt16(current)
        current += 1
        return pid
    }

    mutating func registerResult(
        pid: UInt16,
        success: Bool,
        response: String,
        latency: Double
    ) {
        // Sequential search intentionally ignores scan results.
    }
    
    mutating func seek(to pid: UInt16) {
        if pid <= start {
            current = Int(start)
        } else if pid > end {
            current = Int(end) + 1
        } else {
            current = Int(pid)
        }
    }

}
