//
//  StorageGridView.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 15/07/2026.
//


import SwiftUI

struct StorageGridView<Item: Identifiable>: View {

    let items: [Item]
    let content: (Item) -> AnyView
    let spacing: CGFloat
    let emptyView: AnyView?

    private var columns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 120, maximum: 180), spacing: spacing)
        ]
    }

    var body: some View {
        ScrollView {
            if items.isEmpty {
                if let emptyView {
                    emptyView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                }
            } else {
                gridContent
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    @ViewBuilder
    private var gridContent: some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(items) { item in
                content(item)
            }
        }
        .padding()
    }
    
    init(
        items: [Item],
        spacing: CGFloat = 16,
        emptyView: AnyView? = nil,
        content: @escaping (Item) -> AnyView
    ) {
        self.items = items
        self.spacing = spacing
        self.emptyView = emptyView
        self.content = content
    }
}


private struct StorageGridDemoItem: Identifiable {
    let id = UUID()
    let title: String
}

private let storageGridPreviewItems = [
    StorageGridDemoItem(title: "Logs"),
    StorageGridDemoItem(title: "Profiles"),
    StorageGridDemoItem(title: "Cache"),
    StorageGridDemoItem(title: "Exports")
]

#Preview {
    StorageGridView(items: storageGridPreviewItems) { item in
        AnyView(
            RoundedRectangle(cornerRadius: 16)
                .fill(.quaternary)
                .frame(height: 120)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .font(.largeTitle)
                        Text(item.title)
                            .font(.headline)
                    }
                }
        )
    }
}

