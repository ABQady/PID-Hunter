//
//  Untitled.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 15/07/2026.
//

import Foundation
import SwiftUI

struct StorageItem: Identifiable, Hashable {

    enum Kind: String, Codable {
        case folder
        case file

        var icon: String {
            switch self {
            case .folder:
                return "folder.fill"
            case .file:
                return "doc.text.fill"
            }
        }

        var isFolder: Bool {
            self == .folder
        }

        var sortOrder: Int {
            switch self {
            case .folder: return 0
            case .file: return 1
            }
        }
    }

    let id: URL
    let url: URL
    let name: String
    let kind: Kind
    let size: Int64
    let modifiedDate: Date

    static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    var isFolder: Bool {
        kind.isFolder
    }

    var fileExtension: String {
        url.pathExtension.lowercased()
    }

    var formattedSize: String {
        Self.byteFormatter.string(fromByteCount: size)
    }

    var subtitle: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: modifiedDate)
    }
    
    private static func directorySize(at url: URL) -> Int64 {

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true else {
                continue
            }

            total += Int64(values.fileSize ?? 0)
        }

        return total
    }
    
    init?(url: URL) {
        guard let values = try? url.resourceValues(forKeys: [
            .isDirectoryKey,
            .fileSizeKey,
            .contentModificationDateKey
        ]) else {
            return nil
        }

        self.id = url
        self.url = url
        self.name = url.lastPathComponent
        self.kind = values.isDirectory == true ? .folder : .file
        if values.isDirectory == true {
            self.size = Self.directorySize(at: url)
        } else {
            self.size = Int64(values.fileSize ?? 0)
        }
        self.modifiedDate = values.contentModificationDate ?? .distantPast
    }
}
