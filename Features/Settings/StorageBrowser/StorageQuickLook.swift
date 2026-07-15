//
//  StorageQuickLook.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 15/07/2026.
//

import SwiftUI
import QuickLook

struct StorageQuickLook: View {

    let url: URL
    let title: String?

    @Environment(\.dismiss) private var dismiss

    init(
        url: URL,
        title: String? = nil
    ) {
        self.url = url
        self.title = title
    }

    var body: some View {
        NavigationStack {
            preview
                .navigationTitle(title ?? url.lastPathComponent)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    toolbarContent
                }
        }
    }

    private var preview: some View {
        QuickLookPreview(url: url)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Done") {
                dismiss()
            }
        }
    }
}

private struct QuickLookPreview: UIViewControllerRepresentable {

    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = makeController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(
        _ uiViewController: QLPreviewController,
        context: Context
    ) {
        guard context.coordinator.url != url else {
            return
        }

        context.coordinator.url = url
        uiViewController.reloadData()
    }

func makeCoordinator() -> Coordinator {
    Coordinator(url: url)
}

    private func makeController() -> QLPreviewController {
        QLPreviewController()
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {

        var url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(
            in controller: QLPreviewController
        ) -> Int {
            1
        }

        func previewController(
            _ controller: QLPreviewController,
            previewItemAt index: Int
        ) -> QLPreviewItem {
            url as NSURL
        }
    }
}
