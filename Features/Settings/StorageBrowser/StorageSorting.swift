//
//  StorageSorting.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 15/07/2026.
//

import Foundation

struct StorageSorting {

    enum Direction: String, CaseIterable {
        case ascending
        case descending

        mutating func toggle() {
            self = self == .ascending ? .descending : .ascending
        }
    }

    static func sort(
        _ items: [StorageItem],
        by mode: StorageBrowserView.SortMode,
        direction: Direction = .ascending
    ) -> [StorageItem] {

        let sorted = items.sorted {
            compare($0, $1, by: mode)
        }

        guard direction == .descending else {
            return sorted
        }

        return Array(sorted.reversed())
    }

    // MARK: - Private

    private static func compare(
        _ lhs: StorageItem,
        _ rhs: StorageItem,
        by mode: StorageBrowserView.SortMode
    ) -> Bool {

        // Always keep folders before files.
        if lhs.kind != rhs.kind {
            return lhs.kind.sortOrder < rhs.kind.sortOrder
        }

        switch mode {

        case .name:
            return compareName(lhs, rhs)

        case .date:
            return compareDate(lhs, rhs)

        case .size:
            return compareSize(lhs, rhs)

        case .type:
            return compareType(lhs, rhs)
        }
    }

    private static func compareName(
        _ lhs: StorageItem,
        _ rhs: StorageItem
    ) -> Bool {

        lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private static func compareDate(
        _ lhs: StorageItem,
        _ rhs: StorageItem
    ) -> Bool {

        if lhs.modifiedDate != rhs.modifiedDate {
            return lhs.modifiedDate < rhs.modifiedDate
        }

        return compareName(lhs, rhs)
    }

    private static func compareSize(
        _ lhs: StorageItem,
        _ rhs: StorageItem
    ) -> Bool {

        if lhs.size != rhs.size {
            return lhs.size < rhs.size
        }

        return compareName(lhs, rhs)
    }

    private static func compareType(
        _ lhs: StorageItem,
        _ rhs: StorageItem
    ) -> Bool {

        let lhsExtension = lhs.fileExtension.lowercased()
        let rhsExtension = rhs.fileExtension.lowercased()

        if lhsExtension != rhsExtension {
            return lhsExtension < rhsExtension
        }

        return compareName(lhs, rhs)
    }
}
