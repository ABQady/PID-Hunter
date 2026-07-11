//
//  StoredKnowledgeSheet.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 11/07/2026.
//

import SwiftUI

struct StoredKnowledgeSheet: View {

    let profile: BikeProfile
    let classification: DiscoveryClassification

    @State private var searchText = ""
    @State private var selectedHeader: String? = nil
    @State private var selectedMode: String? = nil
    @State private var isSelectionMode = false
    @State private var selectedKeys = Set<DiscoveryKey>()
    private struct ExportedFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    @State private var exportedFile: ExportedFile?


    private var discoveries: [(key: DiscoveryKey, value: BikeKnowledge)] {
        profile.discoveries
            .filter { $0.value.classification == classification }
            .filter { item in
                (selectedHeader == nil || item.key.header == selectedHeader!) &&
                (selectedMode == nil || item.key.mode == selectedMode!)
            }
            .filter { item in
                guard !searchText.isEmpty else { return true }
                let query = searchText.lowercased()
                return item.key.request.lowercased().contains(query)
                    || item.key.header.lowercased().contains(query)
                    || item.key.mode.lowercased().contains(query)
            }
            .sorted { $0.key.request < $1.key.request }
    }

    private var availableHeaders: [String] {
        Array(Set(profile.discoveries.map { $0.key.header })).sorted()
    }

    private var availableModes: [String] {
        Array(Set(profile.discoveries.map { $0.key.mode })).sorted()
    }

    var body: some View {

        NavigationStack {

            ScrollView {

                LazyVStack(spacing: 12) {

                    ForEach(discoveries, id: \.key) { item in

                        if isSelectionMode {
                            StoredPIDCard(
                                key: item.key,
                                knowledge: item.value,
                                isSelectionMode: true,
                                isSelected: selectedKeys.contains(item.key),
                                onTap: {
                                    if selectedKeys.contains(item.key) {
                                        selectedKeys.remove(item.key)
                                    } else {
                                        selectedKeys.insert(item.key)
                                    }
                                }
                            )
                        } else {
                            StoredPIDCard(
                                key: item.key,
                                knowledge: item.value
                            )
                        }

                    }

                }
                .padding()

            }
            .navigationTitle(
                isSelectionMode
                    ? "\(selectedKeys.count) Selected"
                    : "\(classification.title) (\(discoveries.count))"
            )
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search PID, Header or Mode")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Picker("Header", selection: $selectedHeader) {
                            Text("All Headers").tag(String?.none)
                            ForEach(availableHeaders, id: \.self) { header in
                                Text(header).tag(Optional(header))
                            }
                        }

                        Picker("Mode", selection: $selectedMode) {
                            Text("All Modes").tag(String?.none)
                            ForEach(availableModes, id: \.self) { mode in
                                Text(mode).tag(Optional(mode))
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }

                    Button(isSelectionMode ? "Done" : "Select") {
                        isSelectionMode.toggle()
                        if !isSelectionMode {
                            selectedKeys.removeAll()
                        }
                    }

                    if isSelectionMode {
                        Button("All") {
                            selectedKeys = Set(discoveries.map(\.key))
                        }

                        Button("Clear") {
                            selectedKeys.removeAll()
                        }

                        Button {
                            let exportItems: [(key: DiscoveryKey, value: BikeKnowledge)]

                            if selectedKeys.isEmpty {
                                exportItems = discoveries
                            } else {
                                exportItems = discoveries.filter { selectedKeys.contains($0.key) }
                            }

                            do {
                                let url = try Exporter.exportKnowledge(exportItems)
                                exportedFile = ExportedFile(url: url)
                            } catch {
                                Logger.shared.error("❌ Failed to export stored knowledge: \(error.localizedDescription)")
                            }
                        } label: {
                            if selectedKeys.isEmpty {
                                Label("Export All", systemImage: "square.and.arrow.up")
                            } else {
                                Label("Export (\(selectedKeys.count))", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                }
            }

        }
        .sheet(item: $exportedFile, onDismiss: {
            exportedFile = nil
        }) { file in
            ShareSheet(activityItems: [file.url])
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)

    }

}
