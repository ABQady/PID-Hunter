//
//  BikeProfileCard.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 10/07/2026.
//

import SwiftUI

struct BikeProfileContext {
    let profile: BikeProfile
    let analytics: BikeAnalytics
}

struct BikeProfileCard: View {

    @Environment(BikeProfileManager.self) private var manager
    @State private var displayName = ""
    @FocusState private var nameFieldFocused: Bool
    @AppStorage("bikeProfileCardExpanded") private var rememberExpanded = false

    @State private var exportedURL: URL?
    @State private var showDeleteConfirmation = false
    @State private var isRenaming = false

    // New state properties for profile creation prompt and ECU alert
    @State private var showNewProfilePrompt = false
    @State private var newProfileName = ""
    @State private var showECUAlert = false

    let context: BikeProfileContext?

    var body: some View {
        let profile = context?.profile
        let analytics = context?.analytics

        DisclosureGroup(isExpanded: $rememberExpanded) {
            if let profile, let analytics {
                VStack(alignment: .leading, spacing: 12) {
                    infoRow("Protocol", profile.fingerprint.protocolName)
                    infoRow("VIN", profile.fingerprint.decodedVIN ?? "-")
                    infoRow("Calibration", profile.fingerprint.decodedCalibrationID.isEmpty ? "-" : profile.fingerprint.decodedCalibrationID)

                    Divider()

                    HStack(spacing: 24) {
                        statistic("Known", value: "\(analytics.totalRequests)")
                        statistic("Coverage", value: analytics.coverageString)
                        statistic("Version", value: "v\(profile.schemaVersion)")
                        Spacer(minLength: 0)
                    }

                    ProgressView(value: analytics.coverage)
                    Text(analytics.coverageString + " of the request space discovered")                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Divider()

                    HStack {
                        Button {
                            if !BluetoothManager.shared.isConnected || ECUInfo.shared.fingerprint.id.isEmpty {
                                showECUAlert = true
                            } else {
                                newProfileName = ""
                                showNewProfilePrompt = true
                            }
                        } label: {
                            Label("New", systemImage: "plus")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                        }

                        Button {
                            displayName = profile.displayName
                            isRenaming = true
                            DispatchQueue.main.async {
                                nameFieldFocused = true
                            }
                        } label: {
                            Label("Rename", systemImage: "pencil")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                        }

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                        }

                        Button {
                            do {
                                exportedURL = try Exporter.export(profile)
                            } catch {
                                Logger.shared.error("Failed to export Bike Profile: \(error.localizedDescription)")
                            }
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderless)
                    
                    if isRenaming {
                        TextField("Bike Name", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                            .focused($nameFieldFocused)
                            .onSubmit {
                                manager.renameSelectedProfile(to: displayName)
                                isRenaming = false
                                nameFieldFocused = false
                            }
                            .onChange(of: nameFieldFocused) { _, focused in
                                if !focused {
                                    isRenaming = false
                                }
                            }

                        Text("Give this motorcycle a friendly name. The fingerprint is still used internally.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if manager.isDirty {
                        Label("Unsaved changes", systemImage: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    

                    HStack {
                        Label(
                            manager.isDirty ? "Modified" : "Loaded",
                            systemImage: manager.isDirty ? "circle.fill" : "checkmark.circle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(manager.isDirty ? .orange : .green)

                        Spacer()

                        Text("Schema v\(profile.schemaVersion)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 16) {
                    ContentUnavailableView(
                        "No Bike Profile",
                        systemImage: "motorcycle",
                        description: Text("Connect to a motorcycle to create your first Bike Profile.")
                    )

                    Button {
                        if !BluetoothManager.shared.isConnected || ECUInfo.shared.fingerprint.id.isEmpty {
                            showECUAlert = true
                        } else {
                            newProfileName = ""
                            showNewProfilePrompt = true
                        }
                    } label: {
                        Label("Create First Profile", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        } label: {
            HStack {
                Image(systemName: "motorcycle")
                Text("Bike Profile")
                Spacer()
                Picker("", selection: Binding(
                    get: { manager.displayedProfile?.fingerprint.id ?? "" },
                    set: { selectedID in
                        if let selected = manager.availableProfiles.first(where: { $0.fingerprint.id == selectedID }) {
                            manager.selectProfile(selected)
                        }
                    }
                )) {
                    ForEach(manager.availableProfiles, id: \.fingerprint.id) { profile in
                        Text(profile.displayName)
                            .tag(profile.fingerprint.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            .font(.headline)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            manager.reloadProfiles()
        }
        .alert("No ECU Connected", isPresented: $showECUAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Connect to an ECU first before creating a new Bike Profile.")
        }
        .alert("New Bike Profile", isPresented: $showNewProfilePrompt) {
            TextField("Bike Name", text: $newProfileName)
            Button("Create") {
                guard BluetoothManager.shared.isConnected,
                      !ECUInfo.shared.fingerprint.id.isEmpty else {
                    showECUAlert = true
                    return
                }
                let trimmed = newProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
                manager.createProfileFromCurrent(named: trimmed.isEmpty ? nil : trimmed)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a friendly name for this motorcycle.")
        }
        .confirmationDialog(
            "Delete Bike Profile?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let profile {
                    manager.deleteProfile(profile)
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \(profile?.displayName ?? "this bike profile")? This action cannot be undone.")
        }
        .sheet(isPresented: Binding(
            get: { exportedURL != nil },
            set: { if !$0 { exportedURL = nil } }
        )) {
            if let exportedURL {
                ShareSheet(activityItems: [exportedURL])
            }
        }
    }

    @ViewBuilder
    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .textSelection(.enabled)
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private func statistic(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .monospacedDigit()
        }
    }
}


#Preview {
    let previewProfile = BikeProfile(
        fingerprint: BikeFingerprint(
            protocolName: "ISO 14230-4",
            vinHex: "00000000000000000",
            calibrationHex: "4D344C2F3445433834313930"
        )
    )
    ScrollView {
        BikeProfileCard(
            context: BikeProfileContext(
                profile: previewProfile,
                analytics: BikeAnalytics(profile: previewProfile)
            )
        )
            .padding()
            .environment(BikeProfileManager.shared)
    }
}
