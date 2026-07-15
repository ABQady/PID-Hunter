
//
//  StorageTypes.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 15/07/2026.
//

import Foundation

extension StorageBrowserView {

    enum ViewMode: String, CaseIterable, Identifiable {
        case list
        case grid

        var id: Self { self }
    }

    enum SortMode: String, CaseIterable, Identifiable {
        case name = "Name"
        case date = "Date"
        case size = "Size"
        case type = "Type"

        var id: Self { self }
    }
}

enum StorageLocation: String, CaseIterable, Identifiable {
    case applicationSupport
    case documents
    case caches

    var id: Self { self }

    var title: String {
        switch self {
        case .applicationSupport:
            return "Application Support"
        case .documents:
            return "Documents"
        case .caches:
            return "Caches"
        }
    }
}

enum PreviewType {
    case quickLook
    case json
    case csv
    case log
    case image
    case unsupported
}

enum SelectionMode {
    case inactive
    case single
    case multiple
}

