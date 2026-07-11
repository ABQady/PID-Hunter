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
    @State private var selectedRecords = Set<DiscoveryRecord>()
    private struct ExportedFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    @State private var exportedFile: ExportedFile?


    private var discoveries: [DiscoveryRecord] {
        profile.discoveries
            .filter { $0.classification == classification }
            .filter {
                (selectedHeader == nil || $0.header == selectedHeader!) &&
                (selectedMode == nil || $0.mode == selectedMode!)
            }
            .filter {
                guard !searchText.isEmpty else { return true }
                let query = searchText.lowercased()
                return $0.request.lowercased().contains(query)
                    || $0.header.lowercased().contains(query)
                    || $0.mode.lowercased().contains(query)
            }
            .sorted { $0.request < $1.request }
    }

    private var availableHeaders: [String] {
        Array(Set(profile.discoveries.map { $0.header })).sorted()
    }

    private var availableModes: [String] {
        Array(Set(profile.discoveries.map { $0.mode })).sorted()
    }

    var body: some View {

        NavigationStack {

            ScrollView {

                LazyVStack(spacing: 12) {

                    ForEach(discoveries, id: \.self) { record in
                        if isSelectionMode {
                            StoredPIDCard(
                                record: record,
                                isSelectionMode: true,
                                isSelected: selectedRecords.contains(record),
                                onTap: {
                                    if selectedRecords.contains(record) {
                                        selectedRecords.remove(record)
                                    } else {
                                        selectedRecords.insert(record)
                                    }
                                }
                            )
                        } else {
                            StoredPIDCard(
                                record: record
                            )
                        }
                    }

                }
                .padding()

            }
            .navigationTitle(
                isSelectionMode
                    ? "\(selectedRecords.count) Selected"
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
                            selectedRecords.removeAll()
                        }
                    }

                    if isSelectionMode {
                        Button("All") {
                            selectedRecords = Set<DiscoveryRecord>(discoveries)
                        }

                        Button("Clear") {
                            selectedRecords.removeAll()
                        }

                        Button {
                            let exportItems: [DiscoveryRecord]

                            if selectedRecords.isEmpty {
                                exportItems = discoveries
                            } else {
                                exportItems = discoveries.filter { record in
                                    selectedRecords.contains(record)
                                }
                            }

                            do {
                                let url = try Exporter.exportKnowledge(exportItems)
                                exportedFile = ExportedFile(url: url)
                            } catch {
                                Logger.shared.error("❌ Failed to export stored knowledge: \(error.localizedDescription)")
                            }
                        } label: {
                            if selectedRecords.isEmpty {
                                Label("Export All", systemImage: "square.and.arrow.up")
                            } else {
                                Label("Export (\(selectedRecords.count))", systemImage: "square.and.arrow.up")
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
