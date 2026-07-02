//
//  PIDQueue.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//

import Foundation

struct PIDQueue {

    private var storage: [UInt16] = []
    private var queued: Set<UInt16> = []
    private var head = 0

    var isEmpty: Bool {
        head >= storage.count
    }

    var count: Int {
        storage.count - head
    }

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

        if head > 64 && head * 2 >= storage.count {
            storage.removeFirst(head)
            head = 0
        }

        if head == storage.count {
            clear()
        }

        return pid
    }

    mutating func clear() {
        storage.removeAll(keepingCapacity: true)
        queued.removeAll(keepingCapacity: true)
        head = 0
    }

    mutating func reserveCapacity(_ capacity: Int) {
        storage.reserveCapacity(capacity)
    }

    func contains(_ pid: UInt16) -> Bool {
        queued.contains(pid)
    }
}
