//
//  StorageService.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 15/07/2026.
//

import Foundation

@MainActor
final class StorageService: ObservableObject {

    static let shared = StorageService()

    @Published private(set) var items: [StorageItem] = []
    @Published private(set) var currentDirectory: URL?
    @Published private(set) var currentLocation: StorageLocation = .applicationSupport

    private let fileManager = FileManager.default
    let navigation = NavigationEngine()
    
    var isShowingRoot: Bool {
        currentDirectory == nil
    }

    private init() {}

    private func setCurrentDirectory(_ directory: URL?) {
        currentDirectory = directory
        refreshCurrentLocation()
    }

    func open(_ directory: URL) {
        navigation.push(directory)
        setCurrentDirectory(navigation.current)
    }

    func navigate(to index: Int) {
        guard let directory = navigation.navigateToBreadcrumb(index) else {
            return
        }
        setCurrentDirectory(directory)
    }

    func goUp() {

        if navigation.history.count <= 1 {
            openRoot()
            return
        }

        guard let directory = navigation.up() else {
            openRoot()
            return
        }

        setCurrentDirectory(directory)
    }
    
    func open(_ location: StorageLocation) {

        let url: URL?

        switch location {
        case .applicationSupport:
            url = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first

        case .documents:
            url = fileManager.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first

        case .caches:
            url = fileManager.urls(
                for: .cachesDirectory,
                in: .userDomainMask
            ).first
        }

        guard let url else {
            return
        }

        currentLocation = location
        navigation.reset(to: url)
        setCurrentDirectory(url)
    }
    
    func openRoot() {
        currentDirectory = nil
        items = []
        navigation.clearHistory()
    }

    var breadcrumbComponents: [String] {
        navigation.breadcrumbComponents
    }

    func refresh() {
        refreshCurrentLocation()
    }

    private func refreshCurrentLocation() {

        guard let currentDirectory else {
            return
        }
        publish(
            loadItems(from: currentDirectory)
        )
    }

    private func loadItems(from directory: URL) -> [StorageItem] {
        let urls = contents(of: directory)
        let items = urls.compactMap(StorageItem.init)

        return StorageSorting.sort(
            items,
            by: .name
        )
    }

    private func publish(_ items: [StorageItem]) {

        self.items = items

    }
    func goBack() {

        guard navigation.canGoBack else {
            if currentDirectory != nil {
                openRoot()
            }
            return
        }

        guard let directory = navigation.back() else {
            openRoot()
            return
        }

        setCurrentDirectory(directory)
    }

    func goForward() {
        guard let directory = navigation.forward() else {
            return
        }

        setCurrentDirectory(directory)
    }

    private func contents(of directory: URL) -> [URL] {
        (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .fileSizeKey,
                .contentModificationDateKey
            ],
            options: [.skipsHiddenFiles]
        )) ?? []
    }
}
