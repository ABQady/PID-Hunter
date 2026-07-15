//
//import UIKit
//
//#if targetEnvironment(macCatalyst)
//import AppKit
//#endif
//
//struct ActivityView: UIViewControllerRepresentable {
//    let items: [Any]
//
//    func makeUIViewController(context: Context) -> UIActivityViewController {
//        UIActivityViewController(activityItems: items, applicationActivities: nil)
//    }
//
//    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
//}
////
////  AppStorageViewer.swift
////  PID Hunter
////
////  Created by Ahmed Al Qady on 12/07/2026.
////
//import SwiftUI
//import UniformTypeIdentifiers
//
//struct TextDocument: Identifiable {
//    let id = UUID()
//    let url: URL
//}
//
//struct SharedItem: Identifiable {
//    let id = UUID()
//    let url: URL
//}
//
//struct AppStorageViewer: View {
//
//    @Environment(\.dismiss) private var dismiss
//
//    enum InitialLocation {
//        case documents
//        case applicationSupport
//        case caches
//    }
//
//    let initialLocation: InitialLocation?
//
//    init(initialLocation: InitialLocation? = nil) {
//        self.initialLocation = initialLocation
//    }
//
//    @State private var nodes: [StorageNode] = []
//    @State private var selectedFile: StorageFile?
//    @State private var textDocument: TextDocument?
//    @State private var showDeleteAlert = false
//    @State private var sharedItem: SharedItem?
//    @State private var expandedFolders: Set<URL> = []
//
//    var body: some View {
//        NavigationStack {
//            List {
//                ForEach(nodes) { node in
//                    StorageNodeRow(
//                        node: node,
//                        expandedFolders: $expandedFolders,
//                        preview: preview,
//                        copy: copy,
//                        copyFolder: copyFolder,
//                        shareFolder: { url in sharedItem = SharedItem(url: url) },
//                        deleteFile: { file in selectedFile = file; showDeleteAlert = true },
//                        deleteFolder: { url in
//                            if let file = StorageFile(url: url) {
//                                selectedFile = file
//                                showDeleteAlert = true
//                            }
//                        },
//                        icon: icon
//                    )
//                }
//            }
//            .navigationTitle("App Storage")
//            .toolbar {
//
//                ToolbarItem(placement: .cancellationAction) {
//                    Button("Close") {
//                        dismiss()
//                    }
//                }
//
//                ToolbarItem(placement: .primaryAction) {
//                    Button {
//                        reload()
//                    } label: {
//                        Image(systemName: "arrow.clockwise")
//                    }
//                }
//            }
//            .onAppear(perform: reload)
//            .sheet(item: $textDocument) { document in
//                TextFileViewer(url: document.url)
//            }
//            .sheet(item: $sharedItem) { item in
//                ActivityView(items: [item.url])
//            }
//            .alert("Are you sure you want to fuck this file?",
//                   isPresented: $showDeleteAlert) {
//
//                Button("Delete", role: .destructive) {
//                    if let file = selectedFile {
//                        try? FileManager.default.removeItem(at: file.url)
//                        reload()
//                    }
//                }
//
//                Button("Cancel", role: .cancel) {}
//
//            }
//        }
//    }
//
//    // MARK: - Helpers
//
//    private func reload() {
//        let fm = FileManager.default
//        var newNodes: [StorageNode] = []
//        var documentsURL: URL?
//        var supportURL: URL?
//        var cachesURL: URL?
//        if let documents = fm.urls(
//            for: .documentDirectory,
//            in: .userDomainMask
//        ).first {
//            documentsURL = documents
//            newNodes.append(
//                makeTree(
//                    url: documents,
//                    displayName: "Documents"
//                )
//            )
//        }
//        if let support = fm.urls(
//            for: .applicationSupportDirectory,
//            in: .userDomainMask
//        ).first {
//            supportURL = support
//            newNodes.append(
//                makeTree(
//                    url: support,
//                    displayName: "Application Support"
//                )
//            )
//        }
//        if let caches = fm.urls(
//            for: .cachesDirectory,
//            in: .userDomainMask
//        ).first {
//            cachesURL = caches
//            newNodes.append(
//                makeTree(
//                    url: caches,
//                    displayName: "Caches"
//                )
//            )
//        }
//        nodes = newNodes
//        guard let initialLocation else { return }
//
//        switch initialLocation {
//        case .documents:
//            if let documentsURL {
//                expandedFolders.insert(documentsURL)
//            }
//        case .applicationSupport:
//            if let supportURL {
//                expandedFolders.insert(supportURL)
//            }
//        case .caches:
//            if let cachesURL {
//                expandedFolders.insert(cachesURL)
//            }
//        }
//        // Do not clear expandedFolders; preserve expansion state.
//    }
//    private func preview(_ file: StorageFile) {
//
//        selectedFile = file
//
//        switch file.url.pathExtension.lowercased() {
//
//        case "json", "log", "txt", "csv", "jsonl":
//            textDocument = TextDocument(url: file.url)
//
//        default:
//            break
//        }
//    }
//
//    private func copy(_ file: StorageFile) {
//
//#if targetEnvironment(macCatalyst)
//        let pasteboard = NSPasteboard.general
//        pasteboard.clearContents()
//        pasteboard.writeObjects([file.url as NSURL])
//
//#elseif os(iOS)
//        sharedItem = SharedItem(url: file.url)
//#endif
//    }
//
//    private func copyFolder(_ node: StorageNode) {
//        guard let sourceURL = node.url else { return }
//
//        let coordinator = NSFileCoordinator()
//        var coordinationError: NSError?
//
//        coordinator.coordinate(
//            readingItemAt: sourceURL,
//            options: .forUploading,
//            error: &coordinationError
//        ) { zippedURL in
//            do {
//                let fm = FileManager.default
//                let destination = fm.temporaryDirectory
//                    .appendingPathComponent(sourceURL.lastPathComponent)
//                    .appendingPathExtension("zip")
//
//                if fm.fileExists(atPath: destination.path) {
//                    try fm.removeItem(at: destination)
//                }
//
//                try fm.copyItem(at: zippedURL, to: destination)
//
//#if targetEnvironment(macCatalyst)
//                let pasteboard = NSPasteboard.general
//                pasteboard.clearContents()
//                pasteboard.writeObjects([destination as NSURL])
//
//#elseif os(iOS)
//                sharedItem = SharedItem(url: destination)
//#endif
//
//            } catch {
//                print("Failed to export ZIP: \(error)")
//            }
//        }
//
//        if let coordinationError {
//            print("ZIP coordination failed: \(coordinationError)")
//        }
//    }
//
//    private func icon(for url: URL) -> String {
//
//        switch url.pathExtension.lowercased() {
//
//        case "json":
//            return "curlybraces"
//
//        case "csv":
//            return "tablecells"
//
//        case "log":
//            return "doc.text"
//
//        default:
//            return "doc"
//        }
//    }
//    
//    private func relativePath(_ url: URL) -> String {
//
//        let fm = FileManager.default
//
//        if let documents = fm.urls(
//            for: .documentDirectory,
//            in: .userDomainMask
//        ).first,
//           url.path.hasPrefix(documents.path) {
//
//            return "Documents/" +
//            url.path.replacingOccurrences(
//                of: documents.path + "/",
//                with: ""
//            )
//        }
//
//        if let appSupport = fm.urls(
//            for: .applicationSupportDirectory,
//            in: .userDomainMask
//        ).first,
//           url.path.hasPrefix(appSupport.path) {
//
//            return "Application Support/" +
//            url.path.replacingOccurrences(
//                of: appSupport.path + "/",
//                with: ""
//            )
//        }
//
//        return url.path
//    }
//    
//    private func makeTree(
//        url: URL,
//        displayName: String? = nil
//    ) -> StorageNode {
//
//        let fm = FileManager.default
//
//        let values = try? url.resourceValues(
//            forKeys: [.isDirectoryKey]
//        )
//
//        if values?.isDirectory == true {
//
//            let children =
//                (try? fm.contentsOfDirectory(
//                    at: url,
//                    includingPropertiesForKeys: [
//                        .isDirectoryKey
//                    ]
//                )) ?? []
//
//            return StorageNode(
//                name: displayName ?? url.lastPathComponent,
//                url: url,
//                children: children
//                    .sorted {
//                        $0.lastPathComponent <
//                        $1.lastPathComponent
//                    }
//                    .map {
//                        makeTree(url: $0)
//                    }
//            )
//        }
//
//        return StorageNode(
//            name: url.lastPathComponent,
//            url: url
//        )
//    }
//}
//
//struct StorageNode: Identifiable {
//
//    let id = UUID()
//
//    let name: String
//    let url: URL?
//    let children: [StorageNode]?
//
//    var isDirectory: Bool {
//        children != nil
//    }
//
//    init(name: String,
//         url: URL? = nil,
//         children: [StorageNode]? = nil) {
//
//        self.name = name
//        self.url = url
//        self.children = children
//    }
//}
//
//struct StorageFile {
//
//    let url: URL
//    let modified: Date
//    let size: Int
//
//    init?(url: URL) {
//
//        let values = try? url.resourceValues(
//            forKeys: [
//                .contentModificationDateKey,
//                .fileSizeKey
//            ])
//
//        self.url = url
//        self.modified = values?.contentModificationDate ?? .distantPast
//        self.size = values?.fileSize ?? 0
//    }
//
//    var sizeString: String {
//
//        ByteCountFormatter.string(
//            fromByteCount: Int64(size),
//            countStyle: .file
//        )
//    }
//}
//
//
//// MARK: - Recursive StorageNodeRow
//
//private struct StorageNodeRow: View {
//    let node: StorageNode
//    @Binding var expandedFolders: Set<URL>
//    let preview: (StorageFile) -> Void
//    let copy: (StorageFile) -> Void
//    let copyFolder: (StorageNode) -> Void
//    let shareFolder: (URL) -> Void
//    let deleteFile: (StorageFile) -> Void
//    let deleteFolder: (URL) -> Void
//    let icon: (URL) -> String
//
//    var body: some View {
//        if node.isDirectory, let url = node.url {
//            DisclosureGroup(
//                isExpanded: Binding(
//                    get: { expandedFolders.contains(url) },
//                    set: { expanded in
//                        if expanded {
//                            expandedFolders.insert(url)
//                        } else {
//                            expandedFolders.remove(url)
//                        }
//                    }
//                )
//            ) {
//                if let children = node.children {
//                    ForEach(children) { child in
//                        StorageNodeRow(
//                            node: child,
//                            expandedFolders: $expandedFolders,
//                            preview: preview,
//                            copy: copy,
//                            copyFolder: copyFolder,
//                            shareFolder: shareFolder,
//                            deleteFile: deleteFile,
//                            deleteFolder: deleteFolder,
//                            icon: icon
//                        )
//                    }
//                }
//            } label: {
//                Label(node.name, systemImage: "folder")
//                    .contextMenu {
//                        Button {
//                            copyFolder(node)
//                        } label: {
//                            Label("Copy", systemImage: "doc.on.doc")
//                        }
//                        Button {
//                            shareFolder(url)
//                        } label: {
//                            Label("Share", systemImage: "square.and.arrow.up")
//                        }
//                        Button(role: .destructive) {
//                            deleteFolder(url)
//                        } label: {
//                            Label("Delete", systemImage: "trash")
//                        }
//                    }
//            }
//        } else if let url = node.url, let file = StorageFile(url: url) {
//            VStack(alignment: .leading, spacing: 6) {
//                HStack {
//                    Image(systemName: icon(url))
//                    Text(node.name)
//                        .font(.headline)
//                    Spacer()
//                    Text(file.sizeString)
//                        .foregroundStyle(.secondary)
//                }
//                Text(file.modified.formatted())
//                    .font(.caption)
//                    .foregroundStyle(.secondary)
//                HStack {
//                    Button {
//                        copy(file)
//                    } label: {
//                        Label("Copy", systemImage: "doc.on.doc")
//                            .frame(maxWidth: .infinity)
//                    }
//                    Button(role: .destructive) {
//                        deleteFile(file)
//                    } label: {
//                        Label("Delete", systemImage: "trash")
//                            .frame(maxWidth: .infinity)
//                    }
//                }
//                .frame(maxWidth: .infinity)
//                .buttonStyle(.bordered)
//            }
//            .onTapGesture {
//                preview(file)
//            }
//        }
//    }
//}
//
