//
//  PriorityPIDQueue.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//

import Foundation

struct PriorityPIDQueue {

    private struct Node {
        let pid: UInt16
        var priority: Double
        let sequence: Int
    }

    private var heap: [Node] = []
    private var indices: [UInt16: Int] = [:]
    private var nextSequence = 0

    @inline(__always)
    private func isHigherPriority(_ lhs: Node, than rhs: Node) -> Bool {
        lhs.priority > rhs.priority ||
        (lhs.priority == rhs.priority && lhs.sequence < rhs.sequence)
    }

    var isEmpty: Bool {
        heap.isEmpty
    }

    var count: Int {
        heap.count
    }

    // MARK: - Queue Operations

    mutating func clear() {
        heap.removeAll(keepingCapacity: true)
        indices.removeAll(keepingCapacity: true)
        nextSequence = 0
    }

    mutating func enqueue(pid: UInt16, priority: Double) {
        if let idx = indices[pid] {
            let oldPriority = heap[idx].priority
            if oldPriority == priority {
                return
            }
            heap[idx].priority = priority
            if priority > oldPriority {
                siftUp(from: idx)
            } else {
                siftDown(from: idx)
            }
            return
        }
        let node = Node(pid: pid, priority: priority, sequence: nextSequence)
        nextSequence += 1
        heap.append(node)
        indices[pid] = heap.count - 1
        siftUp(from: heap.count - 1)
    }

    mutating func dequeue() -> UInt16? {
        guard !heap.isEmpty else { return nil }

        let pid = heap[0].pid
        indices.removeValue(forKey: pid)

        if heap.count == 1 {
            heap.removeLast()
            return pid
        }

        heap[0] = heap.removeLast()
        if !heap.isEmpty {
            indices[heap[0].pid] = 0
            siftDown(from: 0)
        }
        return pid
    }

    @inline(__always)
    func contains(_ pid: UInt16) -> Bool {
        indices[pid] != nil
    }

    @inline(__always)
    func priority(of pid: UInt16) -> Double? {
        guard let index = indices[pid] else { return nil }
        return heap[index].priority
    }

    // MARK: - Heap Operations

    private mutating func siftUp(from index: Int) {
        var child = index
        while child > 0 {
            let parent = (child - 1) / 2
            let childNode = heap[child]
            let parentNode = heap[parent]
            if isHigherPriority(childNode, than: parentNode) {
                swapNodes(child, parent)
                child = parent
            } else {
                return
            }
        }
    }

    private mutating func siftDown(from index: Int) {
        var parent = index
        while true {
            let left = parent * 2 + 1
            let right = left + 1
            var candidate = parent

            if left < heap.count {
                let leftNode = heap[left]
                let candNode = heap[candidate]
                if isHigherPriority(leftNode, than: candNode) {
                    candidate = left
                }
            }
            if right < heap.count {
                let rightNode = heap[right]
                let candNode = heap[candidate]
                if isHigherPriority(rightNode, than: candNode) {
                    candidate = right
                }
            }
            guard candidate != parent else { return }
            swapNodes(parent, candidate)
            parent = candidate
        }
    }

    private mutating func swapNodes(_ a: Int, _ b: Int) {
        heap.swapAt(a, b)
        indices[heap[a].pid] = a
        indices[heap[b].pid] = b
    }
}
