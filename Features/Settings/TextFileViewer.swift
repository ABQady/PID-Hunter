//
//  TextFileViewer.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 12/07/2026.
//

import SwiftUI

struct TextFileViewer: View {

    let url: URL

    @Environment(\.dismiss) private var dismiss

    @State private var text = "Loading..."
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {

        NavigationStack {

            Group {

                if isLoading {

                    ProgressView("Loading File...")                        .frame(maxWidth: .infinity,
                               maxHeight: .infinity)

                } else if let error {

                    ContentUnavailableView(
                        "Unable to open file",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )

                } else {

                    TextEditor(text: .constant(text))
                        .font(.system(.body,
                                      design: .monospaced))
                        .textSelection(.enabled)
#if os(iOS)
                        .scrollContentBackground(.hidden)
#endif
                }
            }
            .navigationTitle(url.lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)

            .toolbar {

                ToolbarItem(placement: .cancellationAction) {

                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
#if os(iOS)
                        UIPasteboard.general.string = text
#endif
                    } label: {
                        Label("Copy Contents",
                              systemImage: "doc.on.doc")
                    }
                    .safeAreaInset(edge: .bottom) {

                        HStack {

                            Label(
                                ByteCountFormatter.string(
                                    fromByteCount: Int64(text.utf8.count),
                                    countStyle: .file
                                ),
                                systemImage: "internaldrive"
                            )

                            Spacer()

                            Text(url.pathExtension.uppercased())
                                .foregroundStyle(.secondary)

                        }
                        .padding()
                        .background(.bar)
                    }
                }
            }
        }
        .task {
            await loadFile()
        }
    }

    @MainActor
    private func loadFile() async {

        isLoading = true
        error = nil

        do {

            let contents = try await Task.detached(priority: .userInitiated) {

                let ext = url.pathExtension.lowercased()

                switch ext {

                case "json":

                    let data = try Data(contentsOf: url)

                    let object = try JSONSerialization.jsonObject(
                        with: data
                    )

                    let prettyData =
                        try JSONSerialization.data(
                            withJSONObject: object,
                            options: [
                                .prettyPrinted,
                                .sortedKeys
                            ])

                    return String(
                        decoding: prettyData,
                        as: UTF8.self
                    )

                case "log", "txt", "csv", "jsonl":

                    return try String(
                        contentsOf: url,
                        encoding: .utf8
                    )

                default:

                    if let string = try? String(
                        contentsOf: url,
                        encoding: .utf8
                    ) {

                        return string
                    }

                    return """
                    Binary file

                    \(url.lastPathComponent)

                    Size:
                    \(try Data(contentsOf: url).count) bytes
                    """
                }

            }.value

            text = contents

        } catch {

            self.error = error.localizedDescription
        }

        isLoading = false
    }}
