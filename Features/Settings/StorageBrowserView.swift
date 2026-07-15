//
//  StorageBrowserView.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 15/07/2026.
//

import SwiftUI

struct StorageBrowserView: View {

    @AppStorage("StorageBrowser.ViewMode")
    private var storedViewMode = ViewMode.list.rawValue

    @AppStorage("StorageBrowser.SortMode")
    private var storedSortMode = SortMode.name.rawValue

    @AppStorage("StorageBrowser.SortDirection")
    private var storedSortDirection = SortDirection.ascending.rawValue
// MARK: - Sort Direction Enum

enum SortDirection: String {
    case ascending
    case descending
}

    @State private var searchText = ""
    @StateObject private var storage = StorageService.shared
    @State private var selection = Set<StorageItem.ID>()
    @State private var selectionMode: SelectionMode = .inactive
    @State private var previewURL: URL?
    @State private var isShowingPreview = false
    
    @State private var renameItem: StorageItem?
    @State private var deleteItem: StorageItem?

    @State private var renameText = ""

    @State private var shareItem: StorageItem?

    private let initialLocation: StorageLocation?

    init(initialLocation: StorageLocation? = nil) {
        self.initialLocation = initialLocation
    }

    @ViewBuilder
    private var rootListView: some View {
        StorageListView(
            items: StorageLocation.allCases
        ) { location in
            AnyView(
                StorageRow(
                    icon: "folder",
                    iconColor: .blue,
                    title: location.title,
                    subtitle: nil,
                    detail: nil,
                    showsChevron: true,
                    isSelected: false
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        storage.open(location)
                    }
                }
            )
        }
    }

    @ViewBuilder
    private var rootGridView: some View {
        StorageGridView(items: StorageLocation.allCases) { location in
            AnyView(
                StorageTile(
                    icon: "folder",
                    iconColor: .blue,
                    title: location.title,
                    subtitle: nil,
                    detail: nil,
                    isSelected: false
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        storage.open(location)
                    }
                }
            )
        }
    }

    @ViewBuilder
    private var browserView: some View {
        contentView
    }
    
    // MARK: - Toolbar

    private var toolbar: some ToolbarContent {
        StorageToolbar(
            viewMode: Binding(
                get: { viewMode },
                set: { storedViewMode = $0.rawValue }
            ),
            sortMode: Binding(
                get: { sortMode },
                set: { storedSortMode = $0.rawValue }
            ),
            reload: {
                storage.refresh()
            },
            goBack: {
                storage.goBack()
            },
            goForward: {
                storage.goForward()
            },
            goUp: {
                storage.goUp()
            },
            canGoBack: storage.navigation.canGoBack,
            canGoForward: storage.navigation.canGoForward
        )
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            HStack {
                Text("App Storage")
                    .font(.title)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                Spacer()

                Menu {
                    Button {
                        storedSortMode = SortMode.name.rawValue
                        storedSortDirection = SortDirection.ascending.rawValue
                    } label: {
                        HStack {
                            Image(systemName: sortMode == .name ? "checkmark" : "")
                                .frame(width: 14)
                            Label("Name", systemImage: "textformat")
                        }
                    }
                    Button {
                        storedSortMode = SortMode.type.rawValue
                        storedSortDirection = SortDirection.ascending.rawValue
                    } label: {
                        HStack {
                            Image(systemName: sortMode == .type ? "checkmark" : "")
                                .frame(width: 14)
                            Label("Type", systemImage: "doc")
                        }
                    }
                    Button {
                        storedSortMode = SortMode.size.rawValue
                        storedSortDirection = SortDirection.descending.rawValue
                    } label: {
                        HStack {
                            Image(systemName: sortMode == .size ? "checkmark" : "")
                                .frame(width: 14)
                            Label("Size", systemImage: "externaldrive")
                        }
                    }
                    Divider()
                    Button {
                        storedSortMode = SortMode.date.rawValue
                        storedSortDirection = SortDirection.ascending.rawValue
                    } label: {
                        HStack {
                            Image(systemName: (sortMode == .date && sortDirection == .ascending) ? "checkmark" : "")
                                .frame(width: 14)
                            Label("Oldest First", systemImage: "calendar")
                        }
                    }
                    Button {
                        storedSortMode = SortMode.date.rawValue
                        storedSortDirection = SortDirection.descending.rawValue
                    } label: {
                        HStack {
                            Image(systemName: (sortMode == .date && sortDirection == .descending) ? "checkmark" : "")
                                .frame(width: 14)
                            Label("Newest First", systemImage: "calendar.badge.clock")
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 52, height: 32)
                        .background(.regularMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(.quaternary, lineWidth: 0.5)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                Picker("View", selection: Binding(
                    get: { viewMode },
                    set: { storedViewMode = $0.rawValue }
                )) {
                    Image(systemName: "list.bullet")
                        .tag(ViewMode.list)
                    Image(systemName: "square.grid.2x2")
                        .tag(ViewMode.grid)
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
            }
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, 8)

            breadcrumbView

            if storage.isShowingRoot {
                switch viewMode {
                case .list:
                    rootListView
                case .grid:
                    rootGridView
                }
            } else {
                browserView
            }

            searchBar
            
            Divider()

            HStack {

                Text("\(displayedItems.count) Items")

                Spacer()

                Text(storage.currentLocation.title)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.thinMaterial)
        }
        .animation(.easeInOut(duration: 0.25), value: storage.currentDirectory)
        .animation(.easeInOut(duration: 0.25), value: storage.items)
        .animation(.easeInOut(duration: 0.25), value: storage.isShowingRoot)
        .contentShape(Rectangle())
        .onTapGesture {
#if canImport(UIKit)
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
#endif
        }
        .navigationTitle("Storage")
        .toolbar {
            toolbar
        }
        .onAppear(perform: initialLoad)
        .navigationBarBackButtonHidden(storage.isShowingRoot)
        .sheet(isPresented: $isShowingPreview) {
            if let previewURL {
                StorageQuickLook(url: previewURL)
            }
        }
        .sheet(item: $renameItem) { item in
            NavigationStack {
                Form {
                    TextField("Name", text: $renameText)
                }
                .navigationTitle("Rename")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            renameItem = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Rename") {
                            do {
                                try StorageOperations.shared.renameItem(at: item.url, to: renameText)
                                storage.refresh()
                                selection.removeAll()
                            } catch {
                                print(error)
                            }
                            renameItem = nil
                        }
                        .disabled(renameText.isEmpty)
                    }
                }
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(activityItems: [item.url])
        }
        .alert(
            "Delete Item",
            isPresented: Binding(
                get: { deleteItem != nil },
                set: { if !$0 { deleteItem = nil } }
            ),
            presenting: deleteItem
        ) { item in
            Button("Delete", role: .destructive) {
                do {
                    try StorageOperations.shared.deleteItem(at: item.url)
                    storage.refresh()
                    selection.removeAll()
                } catch {
                    print(error)
                }
                deleteItem = nil
            }
            Button("Cancel", role: .cancel) {
                deleteItem = nil
            }
        } message: { item in
            Text("Delete \"\(item.name)\"?")
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var breadcrumbView: some View {

        StorageBreadcrumb(
            components: storage.isShowingRoot ? ["Storage"] : storage.breadcrumbComponents,
            currentIndex: storage.isShowingRoot ? 0 : storage.breadcrumbComponents.indices.last,
            onSelect: { index in
                if index == 0 {
                    storage.openRoot()
                } else {
                    storage.navigate(to: index)
                }
            }
        )
    }

    @ViewBuilder
    private var searchBar: some View {

        StorageSearchBar(
            text: $searchText,
            onSubmit: {
                // Reserved for future search indexing.
            }
        )
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {

        switch viewMode {

        case .list:
            listContent

        case .grid:
            gridContent
        }
    }

    @ViewBuilder
    private var listContent: some View {

        StorageListView(
            items: displayedItems,
            emptyView: AnyView(
                ContentUnavailableView(
                    "No Files",
                    systemImage: "folder",
                    description: Text("This folder is empty.")
                )
            )
        ) { item in

            AnyView(
                rowView(for: item)
            )
        }
    }

    @ViewBuilder
    private var gridContent: some View {

        StorageGridView(
            items: displayedItems
        ) { item in

            AnyView(
                tileView(for: item)
            )
        }
    }

    // MARK: - Item Views

    @ViewBuilder
    private func rowView(
        for item: StorageItem
    ) -> some View {
        StorageRow(
            icon: item.kind.icon,
            iconColor: item.kind.tintColor,
            title: item.name,
            subtitle: item.subtitle,
            detail: item.formattedSize,
            showsChevron: item.isFolder,
            isSelected: selection.contains(item.id)
        )
        .contentShape(Rectangle())
        .modifier(contextMenu(for: item))
        .fileSwipeActions(
            enabled: true,
            item: item,
            storage: storage,
            selection: $selection,
            renameItem: $renameItem,
            renameText: $renameText,
            deleteItem: $deleteItem,
            shareItem: $shareItem
        )
        .onTapGesture {
            open(item)
        }
    }

    @ViewBuilder
    private func tileView(
        for item: StorageItem
    ) -> some View {

        StorageTile(
            icon: item.kind.icon,
            iconColor: item.kind.tintColor,
            title: item.name,
            subtitle: item.subtitle,
            detail: item.formattedSize,
            isSelected: selection.contains(item.id)
        )
        .modifier(
            contextMenu(for: item)
        )
        .onTapGesture {
            open(item)
        }
    }

    // MARK: - Context Menu

    private func contextMenu(
        for item: StorageItem
    ) -> StorageContextMenu {
        StorageContextMenu(
            isFolder: item.isFolder,
            isEnabled: selectionMode != .multiple,
            open: {
                storage.open(item.url)
            },
            quickLook: { quickLook(item) },
            preview: { preview(item) },
            share: { share(item) },
            rename: { rename(item) },
            duplicate: { duplicate(item) },
            delete: { delete(item) }
        )
    }

    // MARK: - Actions

    private func initialLoad() {

        withAnimation(.easeInOut(duration: 0.25)) {
            if let initialLocation {
                storage.open(initialLocation)
            } else {
                storage.openRoot()
            }
        }
    }

    private func open(
        _ item: StorageItem
    ) {
        if item.isFolder {
            withAnimation(.easeInOut(duration: 0.25)) {
                selection.removeAll()
                selectionMode = .inactive
                storage.open(item.url)
            }
            return
        }
        toggleSelection(item)
    }

    private func toggleSelection(
        _ item: StorageItem
    ) {
        if selection.insert(item.id).inserted {
            return
        }
        selection.remove(item.id)
    }

    private func quickLook(_ item: StorageItem) {
        selection = [item.id]
        previewURL = item.url
        isShowingPreview = true
    }

    private func preview(_ item: StorageItem) {
        previewURL = item.url
        isShowingPreview = true
    }

    private func share(_ item: StorageItem) {
        selection = [item.id]
        shareItem = item
    }

    private func rename(_ item: StorageItem) {
        renameItem = item
        renameText = item.name
    }

    private func duplicate(_ item: StorageItem) {
        do {
            let newURL = try StorageOperations.shared.duplicateItem(at: item.url)
            storage.refresh()
            if let duplicated = storage.items.first(where: { $0.url == newURL }) {
                selection = [duplicated.id]
            }
        } catch {
            print(error)
        }
    }

    private func delete(_ item: StorageItem) {
        deleteItem = item
    }

    // MARK: - State

    private var viewMode: ViewMode {
        ViewMode(rawValue: storedViewMode) ?? .list
    }

    private var sortMode: SortMode {
        SortMode(rawValue: storedSortMode) ?? .name
    }

    private var sortDirection: SortDirection {
        SortDirection(rawValue: storedSortDirection) ?? .ascending
    }

    private var displayedItems: [StorageItem] {
        filteredItems(
            StorageSorting.sort(
                storage.items,
                by: sortMode,
                direction: sortDirection == .ascending ? .ascending : .descending
            )
        )
    }

    private func filteredItems(
        _ items: [StorageItem]
    ) -> [StorageItem] {

        guard !searchText.isEmpty else {
            return items
        }

        return items.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.fileExtension.localizedCaseInsensitiveContains(searchText) ||
            $0.subtitle.localizedCaseInsensitiveContains(searchText)
        }
    }
}



private extension View {

    func fileSwipeActions(
        enabled: Bool,
        item: StorageItem,
        storage: StorageService,
        selection: Binding<Set<StorageItem.ID>>,
        renameItem: Binding<StorageItem?>,
        renameText: Binding<String>,
        deleteItem: Binding<StorageItem?>,
        shareItem: Binding<StorageItem?>
    ) -> some View {

        guard enabled else {
            return AnyView(self)
        }

        return AnyView(
            self
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteItem.wrappedValue = item
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        shareItem.wrappedValue = item
                        selection.wrappedValue = [item.id]
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .tint(.blue)

                    Button {
                        renameItem.wrappedValue = item
                        renameText.wrappedValue = item.name
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .tint(.orange)

                    if !item.isFolder {
                        Button {
                            do {
                                let newURL = try StorageOperations.shared.duplicateItem(at: item.url)
                                storage.refresh()
                                if let duplicated = storage.items.first(where: { $0.url == newURL }) {
                                    selection.wrappedValue = [duplicated.id]
                                }
                            } catch {
                                print(error)
                            }
                        } label: {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                        }
                        .tint(.green)
                    }
                }
        )
    }
}


#Preview {
    NavigationStack {
        StorageBrowserView()
    }
}
