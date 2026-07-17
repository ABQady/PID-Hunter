//
//  StorageContextMenu.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 15/07/2026.
//

import SwiftUI

struct StorageContextMenu: ViewModifier {

    let isFolder: Bool
    let isEnabled: Bool

    let open: () -> Void
    let quickLook: () -> Void
    let preview: () -> Void
    let share: () -> Void
    let rename: () -> Void
    let duplicate: () -> Void
    let delete: () -> Void

    func body(content: Content) -> some View {
        content
            .contextMenu {
                primaryAction

                Divider()

                secondaryActions

                Divider()

                destructiveActions
            }
    }

    // MARK: - Primary

    @ViewBuilder
    private var primaryAction: some View {

        if isFolder {

            Button {
                open()
            } label: {
                Label("Open", systemImage: "folder")
            }
            .disabled(!isEnabled)

        } else {

            Button {
                quickLook()
            } label: {
                Label("Quick Look", systemImage: "eye")
            }
            .disabled(!isEnabled)

            Button {
                preview()
            } label: {
                Label("Preview", systemImage: "doc.text.magnifyingglass")
            }
            .disabled(!isEnabled)
        }
    }

    // MARK: - Secondary

    @ViewBuilder
    private var secondaryActions: some View {

        Button {
            share()
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        .disabled(!isEnabled)

        Button {
            rename()
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        .disabled(!isEnabled)

        Button {
            duplicate()
        } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
        }
        .disabled(!isEnabled)
    }

    // MARK: - Destructive

    @ViewBuilder
    private var destructiveActions: some View {

        Button(role: .destructive) {
            delete()
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .disabled(!isEnabled)
    }
}

extension View {

    func storageContextMenu(
        isFolder: Bool,
        isEnabled: Bool = true,
        open: @escaping () -> Void = {},
        quickLook: @escaping () -> Void = {},
        preview: @escaping () -> Void = {},
        share: @escaping () -> Void = {},
        rename: @escaping () -> Void = {},
        duplicate: @escaping () -> Void = {},
        delete: @escaping () -> Void = {}
    ) -> some View {

        modifier(
            StorageContextMenu(
                isFolder: isFolder,
                isEnabled: isEnabled,
                open: open,
                quickLook: quickLook,
                preview: preview,
                share: share,
                rename: rename,
                duplicate: duplicate,
                delete: delete
            )
        )
    }
}

#Preview {
    RoundedRectangle(cornerRadius: 16)
        .fill(.quaternary)
        .frame(width: 180, height: 120)
        .storageContextMenu(
            isFolder: true,
            isEnabled: true
        )
        .padding()
}
