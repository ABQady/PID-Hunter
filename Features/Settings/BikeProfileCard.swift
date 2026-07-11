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

    let context: BikeProfileContext?

    var body: some View {
        let profile = context?.profile
        let analytics = context?.analytics

        DisclosureGroup(isExpanded: $rememberExpanded) {
            if let profile, let analytics {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Bike Name", text: $displayName)
                        .textFieldStyle(.roundedBorder)
                        .focused($nameFieldFocused)
                        .onAppear {
                            displayName = profile.displayName
                        }
                        .onSubmit {
                            manager.rename(displayName)
                        }
                    Text("Give this motorcycle a friendly name. The fingerprint is still used internally.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if manager.isDirty {
                        Label("Unsaved changes", systemImage: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    infoRow("Header", profile.fingerprint.header)
                    infoRow("Protocol", profile.fingerprint.protocolName)
                    infoRow("VIN", profile.fingerprint.ecuIdentifier ?? "-")
                    infoRow("Calibration", profile.fingerprint.calibrationIdentifier ?? "-")

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
                            do {
                                exportedURL = try Exporter.export(profile)
                            } catch {
                                Logger.shared.error("Failed to export Bike Profile: \(error.localizedDescription)")
                            }
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                    }
                    .buttonStyle(.borderless)

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
                ContentUnavailableView(
                    "No Bike Profile",
                    systemImage: "motorcycle",
                    description: Text("Connect to a motorcycle to create and load its bike profile.")
                )
            }
        } label: {
            HStack {
                Image(systemName: "motorcycle")
                Text("Bike Profile")
                Spacer()

                Text(profile?.displayName ?? "No Bike Connected")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .font(.headline)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
    ScrollView {
        BikeProfileCard(
            context: BikeProfileContext(
                profile: BikeProfile(
                    fingerprint: BikeFingerprint(
                        header: "81F111",
                        protocolName: "ISO 14230-4",
                        ecuIdentifier: "Demo ECU",
                        calibrationIdentifier: "CAL-001"
                    )
                ),
                analytics: BikeAnalytics(
                    profile: BikeProfile(
                        fingerprint: BikeFingerprint(
                            header: "81F111",
                            protocolName: "ISO 14230-4",
                            ecuIdentifier: "Demo ECU",
                            calibrationIdentifier: "CAL-001"
                        )
                    )
                )
            )
        )
            .padding()
            .environment(BikeProfileManager.shared)
    }
}
