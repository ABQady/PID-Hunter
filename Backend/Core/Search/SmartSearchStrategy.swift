//
//  SmartSearchStrategy.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//


import Foundation

struct SmartSearchStrategy: SearchStrategy {

    private var queue = PIDQueue()
    private var visited: Set<UInt16> = []
    private var lastPositivePID: UInt16?
    private var positiveHitCount = 0

    private let neighborhoodRadius: UInt16 = 3

    private var current: Int
    private let start: UInt16
    private let end: UInt16

    init(start: UInt16, end: UInt16) {
        precondition(start <= end)
        self.start = start
        self.end = end
        self.current = Int(start)
    }

    mutating func reset() {
        queue.clear()
        queue.reserveCapacity(64)
        visited.removeAll()
        lastPositivePID = nil
        positiveHitCount = 0
        current = Int(start)
    }

    mutating func seek(to pid: UInt16) {
        if pid <= start {
            current = Int(start)
        } else if pid > end {
            current = Int(end) + 1
        } else {
            current = Int(pid)
        }
        queue.clear()
        visited.removeAll()
        lastPositivePID = nil
        positiveHitCount = 0
        queue.reserveCapacity(64)
    }

    // MARK: - PID Selection
    mutating func nextPID() -> UInt16? {
        while let pid = queue.dequeue() {
            if pid < start || pid > end {
                continue
            }

            guard visited.insert(pid).inserted else { continue }
            if Int(pid) > current {
                current = Int(pid)
            }
            return pid
        }

        while current <= Int(end) {
            let pid = UInt16(current)
            current += 1
            guard visited.insert(pid).inserted else { continue }
            return pid
        }

        return nil
    }

    private func radius(for pid: UInt16) -> UInt16 {
        guard let last = lastPositivePID else {
            return neighborhoodRadius
        }

        let distance = abs(Int(last) - Int(pid))
        guard distance <= Int(neighborhoodRadius) else {
            return neighborhoodRadius
        }

        let boosted = neighborhoodRadius + min(UInt16(positiveHitCount), neighborhoodRadius)
        let maxRadius = min(end - start, UInt16(16))
        return min(boosted, maxRadius)
    }

    // MARK: - Result Processing
    // Expands the search around positive hits.
    mutating func registerResult(
        pid: UInt16,
        success: Bool,
        response: String,
        latency: Double
    ) {
        guard success else { return }

        let upper = response.uppercased()
        guard !upper.isEmpty else { return }

        guard !upper.contains("NO DATA") else { return }
        guard !upper.contains("7F") else { return }

        // Calculate the expansion radius before updating the previous hit.
        let radius = radius(for: pid)

        lastPositivePID = pid
        positiveHitCount += 1

        for offset in 1...Int(radius) {
            let delta = UInt16(offset)

            if pid >= start + delta {
                enqueue(pid - delta)
            }

            if pid <= end - delta {
                enqueue(pid + delta)
            }
        }
    }

    // MARK: - Queue Helpers
    private mutating func enqueue(_ pid: UInt16) {
        guard pid >= start, pid <= end else { return }
        guard !visited.contains(pid) else { return }
        guard !queue.contains(pid) else { return }
        queue.enqueue(pid)
    }
}
