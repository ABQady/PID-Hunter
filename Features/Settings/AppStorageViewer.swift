//
//  AppStorageViewer.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 12/07/2026.
//
import SwiftUI
import UniformTypeIdentifiers

struct JSONDocument: Identifiable {

    let id = UUID()
    let url: URL
}

struct AppStorageViewer: View {

    @Environment(\.dismiss) private var dismiss

    @State private var nodes: [StorageNode] = []
    @State private var selectedFile: StorageFile?
    @State private var jsonDocument: JSONDocument?
    @State private var showDeleteAlert = false

    var body: some View {
        NavigationStack {
            List {

                OutlineGroup(nodes,
                             children: \.children) { node in

                    if node.isDirectory {

                        Label(node.name,
                              systemImage: "folder")

                    } else if let url = node.url,
                              let file = StorageFile(url: url) {

                        VStack(alignment: .leading,
                               spacing: 6) {

                            HStack {

                                Image(systemName: icon(for: url))

                                Text(node.name)
                                    .font(.headline)

                                Spacer()

                                Text(file.sizeString)
                                    .foregroundStyle(.secondary)
                            }

                            Text(file.modified.formatted())
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack {

                                Button("Preview") {
                                    preview(file)
                                }

                                Button("Copy") {
                                    copy(file)
                                }

                                Button(role: .destructive) {

                                    selectedFile = file
                                    showDeleteAlert = true

                                } label: {
                                    Text("Delete")
                                }

                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .navigationTitle("App Storage")
            .toolbar {

                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        reload()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear(perform: reload)
            .sheet(item: $jsonDocument) { document in
                TextFileViewer(url: document.url)
            }
            .alert("Delete file?",
                   isPresented: $showDeleteAlert) {

                Button("Delete", role: .destructive) {
                    if let file = selectedFile {
                        try? FileManager.default.removeItem(at: file.url)
                        reload()
                    }
                }

                Button("Cancel", role: .cancel) {}

            }
        }
    }

    // MARK: - Helpers

    private func reload() {

        let fm = FileManager.default

        nodes.removeAll()

        if let documents = fm.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first {

            nodes.append(
                makeTree(
                    url: documents,
                    displayName: "Documents"
                )
            )
        }

        if let support = fm.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first {

            nodes.append(
                makeTree(
                    url: support,
                    displayName: "Application Support"
                )
            )
        }
    }
    private func preview(_ file: StorageFile) {

        selectedFile = file

        if file.url.pathExtension.lowercased() == "json" {

            jsonDocument = JSONDocument(url: file.url)
            return
        }
    }

    private func copy(_ file: StorageFile) {

#if os(iOS)
        UIPasteboard.general.string =
            (try? String(contentsOf: file.url, encoding: .utf8)) ?? ""
#endif
    }

    private func icon(for url: URL) -> String {

        switch url.pathExtension.lowercased() {

        case "json":
            return "curlybraces"

        case "csv":
            return "tablecells"

        case "log":
            return "doc.text"

        default:
            return "doc"
        }
    }
    
    private func relativePath(_ url: URL) -> String {

        let fm = FileManager.default

        if let documents = fm.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first,
           url.path.hasPrefix(documents.path) {

            return "Documents/" +
            url.path.replacingOccurrences(
                of: documents.path + "/",
                with: ""
            )
        }

        if let appSupport = fm.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first,
           url.path.hasPrefix(appSupport.path) {

            return "Application Support/" +
            url.path.replacingOccurrences(
                of: appSupport.path + "/",
                with: ""
            )
        }

        return url.path
    }
    
    private func makeTree(
        url: URL,
        displayName: String? = nil
    ) -> StorageNode {

        let fm = FileManager.default

        let values = try? url.resourceValues(
            forKeys: [.isDirectoryKey]
        )

        if values?.isDirectory == true {

            let children =
                (try? fm.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [
                        .isDirectoryKey
                    ]
                )) ?? []

            return StorageNode(

                name: displayName ??
                      url.lastPathComponent,

                children: children
                    .sorted {
                        $0.lastPathComponent <
                        $1.lastPathComponent
                    }
                    .map {
                        makeTree(url: $0)
                    }
            )
        }

        return StorageNode(
            name: url.lastPathComponent,
            url: url
        )
    }
}

struct StorageNode: Identifiable {

    let id = UUID()

    let name: String
    let url: URL?
    let children: [StorageNode]?

    var isDirectory: Bool {
        children != nil
    }

    init(name: String,
         url: URL? = nil,
         children: [StorageNode]? = nil) {

        self.name = name
        self.url = url
        self.children = children
    }
}

struct StorageFile {

    let url: URL
    let modified: Date
    let size: Int

    init?(url: URL) {

        let values = try? url.resourceValues(
            forKeys: [
                .contentModificationDateKey,
                .fileSizeKey
            ])

        self.url = url
        self.modified = values?.contentModificationDate ?? .distantPast
        self.size = values?.fileSize ?? 0
    }

    var sizeString: String {

        ByteCountFormatter.string(
            fromByteCount: Int64(size),
            countStyle: .file
        )
    }
}
