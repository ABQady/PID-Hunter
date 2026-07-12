//
//  PIDQueue.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//

import Foundation

struct PIDQueue {

    private static let compactionThreshold = 64

    private var storage: [UInt16] = []
    private var queued: Set<UInt16> = []
    private var head = 0

    var isEmpty: Bool {
        head >= storage.count
    }

    var count: Int {
        storage.count - head
    }

    @inline(__always)
    private var shouldCompact: Bool {
        head > Self.compactionThreshold && head * 2 >= storage.count
    }

    // MARK: - Queue Operations

    mutating func enqueue(_ pid: UInt16) {
        guard queued.insert(pid).inserted else { return }
        storage.append(pid)
    }

    mutating func dequeue() -> UInt16? {
        guard head < storage.count else {
            clear()
            return nil
        }

        let pid = storage[head]
        head += 1
        queued.remove(pid)

        if shouldCompact {
            storage.removeFirst(head)
            head = 0
        }

        if head == storage.count {
            clear()
        }

        return pid
    }

    // MARK: - Utilities

    @inline(__always)
    mutating func clear() {
        storage.removeAll(keepingCapacity: true)
        queued.removeAll(keepingCapacity: true)
        head = 0
    }

    @inline(__always)
    mutating func reserveCapacity(_ capacity: Int) {
        storage.reserveCapacity(capacity)
    }

    @inline(__always)
    func contains(_ pid: UInt16) -> Bool {
        queued.contains(pid)
    }
}
