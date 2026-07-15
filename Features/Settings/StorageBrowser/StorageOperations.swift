//
//  StorageOperations.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 15/07/2026.
//

import Foundation

@MainActor
final class StorageOperations: ObservableObject {

    static let shared = StorageOperations()

    private let fileManager = FileManager.default

    private init() {}

    // MARK: - Queries

    func itemExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    // MARK: - Delete

    func deleteItem(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }

    // MARK: - Duplicate

    @discardableResult
    func duplicateItem(at url: URL) throws -> URL {

        let destination = uniqueDuplicateURL(for: url)

        try copyItem(
            at: url,
            to: destination
        )

        return destination
    }

    // MARK: - Rename

    @discardableResult
    func renameItem(
        at url: URL,
        to newName: String
    ) throws -> URL {

        let destination = destinationURL(
            forRenameFrom: url,
            to: newName
        )

        try moveItem(
            at: url,
            to: destination
        )

        return destination
    }

    // MARK: - Move / Copy

    func moveItem(
        at url: URL,
        to destination: URL
    ) throws {

        try fileManager.moveItem(
            at: url,
            to: destination
        )
    }

    func copyItem(
        at url: URL,
        to destination: URL
    ) throws {

        try fileManager.copyItem(
            at: url,
            to: destination
        )
    }

    // MARK: - Helpers

    private func destinationURL(
        forRenameFrom url: URL,
        to newName: String
    ) -> URL {

        url.deletingLastPathComponent()
            .appendingPathComponent(newName)
    }

    private func uniqueDuplicateURL(
        for url: URL
    ) -> URL {

        let directory = url.deletingLastPathComponent()
        let baseName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension

        var index = 2

        var candidate = directory
            .appendingPathComponent("\(baseName) Copy")
            .appendingPathExtension(ext)

        while itemExists(at: candidate) {

            candidate = directory
                .appendingPathComponent("\(baseName) Copy \(index)")
                .appendingPathExtension(ext)

            index += 1
        }

        return candidate
    }
}
