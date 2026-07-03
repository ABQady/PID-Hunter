//
//  PIDRange.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 03/07/2026.
//
struct PIDRange: Hashable, Codable {
    let start: UInt16
    let end: UInt16

    var isSinglePID: Bool {
        start == end
    }

    var count: UInt16 {
        end - start + 1
    }

    var midpoint: UInt16 {
        start + (end - start) / 2
    }

    func contains(_ pid: UInt16) -> Bool {
        start...end ~= pid
    }

    func intersects(_ other: PIDRange) -> Bool {
        start <= other.end && end >= other.start
    }

    func expanded(by value: UInt16) -> PIDRange {
        PIDRange(
            start: start &- min(start, value),
            end: end &+ value
        )
    }
}
