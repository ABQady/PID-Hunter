//
//  PIDRange.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 03/07/2026.
//
struct PIDRange: Hashable, Codable {
    // MARK: - Derived Values
    let start: UInt16
    let end: UInt16

    @inline(__always)
    var isSinglePID: Bool {
        start == end
    }

    @inline(__always)
    var count: UInt16 {
        end - start + 1
    }

    @inline(__always)
    var midpoint: UInt16 {
        start + (end - start) / 2
    }

    @inline(__always)
    func contains(_ pid: UInt16) -> Bool {
        start...end ~= pid
    }

    @inline(__always)
    func intersects(_ other: PIDRange) -> Bool {
        start <= other.end && end >= other.start
    }

    // MARK: - Transformations
    func expanded(by value: UInt16) -> PIDRange {
        let newStart = start &- min(start, value)
        let newEnd = end &+ value

        return PIDRange(
            start: newStart,
            end: newEnd
        )
    }
}
