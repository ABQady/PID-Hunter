//
//  NavigationEngine.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 15/07/2026.
//

import Foundation

@MainActor
final class NavigationEngine: ObservableObject {

    @Published private(set) var history: [URL] = []
    @Published private(set) var currentIndex: Int = -1

    // MARK: - Current

    var current: URL? {
        guard history.indices.contains(currentIndex) else {
            return nil
        }

        return history[currentIndex]
    }

    var isEmpty: Bool {
        history.isEmpty
    }

    var canGoBack: Bool {
        currentIndex > 0
    }

    var canGoForward: Bool {
        currentIndex >= 0 &&
        currentIndex < history.count - 1
    }

    // MARK: - Navigation

    func reset(to directory: URL) {
        history = [directory]
        currentIndex = 0
    }

    func push(_ directory: URL) {

        guard current != directory else {
            return
        }

        if canGoForward {
            history.removeSubrange((currentIndex + 1)...)
        }

        history.append(directory)
        currentIndex = history.count - 1
    }

    func replace(with directory: URL) {

        guard history.indices.contains(currentIndex) else {
            reset(to: directory)
            return
        }

        history[currentIndex] = directory
    }

    @discardableResult
    private func move(to index: Int) -> URL? {
        guard history.indices.contains(index) else {
            return current
        }

        currentIndex = index
        return current
    }

    @discardableResult
    func back() -> URL? {
        guard canGoBack else {
            return current
        }

        return move(to: currentIndex - 1)
    }

    @discardableResult
    func forward() -> URL? {
        guard canGoForward else {
            return current
        }

        return move(to: currentIndex + 1)
    }

    @discardableResult
    func up() -> URL? {

        guard let current else {
            return nil
        }

        let parent = current.deletingLastPathComponent()

        guard parent != current else {
            return current
        }

        push(parent)
        return parent
    }

    // MARK: - Breadcrumbs

    var breadcrumbComponents: [String] {

        guard !history.isEmpty else {
            return ["Storage"]
        }

        return ["Storage"] + history.map {
            $0.lastPathComponent
        }
    }

    func navigateToBreadcrumb(_ index: Int) -> URL? {

        guard index > 0 else {
            return history.first
        }

        let target = index - 1

        guard history.indices.contains(target) else {
            return current
        }

        history = Array(history.prefix(target + 1))
        return move(to: target)
    }

    // MARK: - Debug

    func clearHistory() {
        history.removeAll()
        currentIndex = -1
    }
}
