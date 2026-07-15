//
//  StorageListView.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 15/07/2026.
//



import SwiftUI

struct StorageListView<Item: Identifiable>: View {

    let items: [Item]
    let row: (Item) -> AnyView
    let emptyView: AnyView?
    let showsSeparators: Bool

    init(
        items: [Item],
        emptyView: AnyView? = nil,
        showsSeparators: Bool = false,
        row: @escaping (Item) -> AnyView
    ) {
        self.items = items
        self.emptyView = emptyView
        self.showsSeparators = showsSeparators
        self.row = row
    }

    var body: some View {
        Group {
            if items.isEmpty {
                if let emptyView {
                    emptyView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                List {
                    ForEach(items) { item in
                        row(item)
                            .listRowInsets(
                                EdgeInsets(
                                    top: 6,
                                    leading: 16,
                                    bottom: 6,
                                    trailing: 16
                                )
                            )
                            .listRowSeparator(showsSeparators ? .visible : .hidden)
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }
}

private struct StorageListDemoItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
}

private let storageListPreviewItems = [
    StorageListDemoItem(title: "Logs", subtitle: "7.4 MB"),
    StorageListDemoItem(title: "Profiles", subtitle: "540 KB"),
    StorageListDemoItem(title: "Cache", subtitle: "124 KB")
]

#Preview {
    StorageListView(items: storageListPreviewItems) { item in
        AnyView(
            HStack(spacing: 14) {
                Image(systemName: "folder.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.headline)

                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(.quaternary.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        )
    }
}
