//
//  StorageToolbar.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 15/07/2026.
//

import SwiftUI

struct StorageToolbar: ToolbarContent {

    @Binding var viewMode: StorageBrowserView.ViewMode
    @Binding var sortMode: StorageBrowserView.SortMode

    let reload: () -> Void
    let goBack: () -> Void
    let goForward: () -> Void
    let goUp: () -> Void

    let canGoBack: Bool
    let canGoForward: Bool

    @ViewBuilder
    private var navigationControls: some View {

        Button(action: goBack) {
            Image(systemName: "chevron.left")
        }
        .disabled(!canGoBack)

        Button(action: goForward) {
            Image(systemName: "chevron.right")
        }
        .disabled(!canGoForward)

        Button(action: goUp) {
            Image(systemName: "arrow.up")
        }
    }

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {

            navigationControls

            Picker("View", selection: $viewMode) {
                Image(systemName: "list.bullet")
                    .tag(StorageBrowserView.ViewMode.list)

                Image(systemName: "square.grid.2x2")
                    .tag(StorageBrowserView.ViewMode.grid)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 130)

            actionsMenu
        }
    }

    @ViewBuilder
    private var actionsMenu: some View {
        Menu {
            Picker("Sort By", selection: $sortMode) {
                ForEach(StorageBrowserView.SortMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: icon(for: mode))
                        .tag(mode)
                }
            }

            Divider()

            Button {
                goUp()
            } label: {
                Label("Up", systemImage: "arrow.up")
            }

            Button {
                reload()
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private func icon(for mode: StorageBrowserView.SortMode) -> String {
        switch mode {
        case .name:
            return "textformat"
        case .date:
            return "calendar"
        case .size:
            return "internaldrive"
        case .type:
            return "doc"
        }
    }
}

#Preview {
    NavigationStack {
        Text("Storage")
            .toolbar {
                StorageToolbar(
                    viewMode: .constant(.list),
                    sortMode: .constant(.name),
                    reload: {},
                    goBack: {},
                    goForward: {},
                    goUp: {},
                    canGoBack: true,
                    canGoForward: false
                )
            }
    }
}
