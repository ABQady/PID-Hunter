//
//  ELMView.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 17/07/2026.
//


import SwiftUI

private enum ProfileLoadState {
    case loading
    case loaded
    case noProfile
}

struct ELMView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var profile: ELMProfile?
    init(profile: ELMProfile) {
        _profile = State(initialValue: profile)
    }
    @State private var isDiscovering = false
    @State private var discoveryFinished = false
    @State private var discoveryTask: Task<Void, Never>?
    @State private var discoveryProgress: Double = 0
    @State private var discoveryTitle = "Preparing discovery..."
    @State private var isLoadingProfile = false
    @State private var availableProfiles: [ELMProfile] = []
    @State private var selectedProfileID = ""
    @State private var loadState: ProfileLoadState = .loading

    private var currentProfile: ELMProfile {
        profile ?? .empty
    }

    private var firmware: String {
        currentProfile.firmware ?? ""
    }
    private var description: String {
        currentProfile.deviceDescription ?? ""
    }
    private var identifier: String {
        currentProfile.deviceIdentifier ?? ""
    }
    private var voltage: String {
        if let voltageValue = currentProfile.voltage {
            return String(format: "%.1f V", voltageValue)
        } else {
            return ""
        }
    }
    private var protocolName: String {
        currentProfile.protocolDescription ?? ""
    }
    private var protocolNumber: String {
        currentProfile.protocolNumber ?? ""
    }
    private var supportedCommands: [String] {
        currentProfile.supportedCommands.map { $0.command }
    }
    private var unsupportedCommands: [String] {
        currentProfile.unsupportedCommands.map { $0.command }
    }

    var body: some View {
        NavigationStack {
            List {
                if loadState == .loading {
                    ProgressView("Loading ELM Profile…")
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }

                if loadState == .noProfile {
                    ContentUnavailableView(
                        "No Profile Found",
                        systemImage: "cpu",
                        description: Text("No saved profile matches the connected adapter. Create a new profile or choose an existing one.")
                    )
                }

                if loadState == .loaded || loadState == .noProfile {
                    VStack(spacing: 16) {
                        Image(systemName: "cpu.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.accentColor)
                        Text("ELM327")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Divider()
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Firmware")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(firmware)
                                    .font(.body)
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                            VStack(alignment: .leading) {
                                Text("Protocol")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(protocolName)
                                    .font(.body)
                                    .fontWeight(.semibold)
                            }
                        }
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Voltage")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(voltage)
                                    .font(.body)
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                        Divider()
                        ProgressView(value: currentProfile.supportRate)
                            .tint(.green)
                            .scaleEffect(x: 1, y: 2, anchor: .center)
                        HStack {
                            Spacer()
                            VStack {
                                Text("\(currentProfile.supportedCommands.count)")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Text("Supported")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack {
                                Text("\(currentProfile.unsupportedCommands.count)")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Text("Unsupported")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack {
                                Text("\(Int(currentProfile.supportRate * 100))%")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Text("Success")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(20)
                    .padding(.vertical)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    Section(header: Text("Profile")) {
                        Picker("Profile", selection: $selectedProfileID) {
                            Text("Create New Profile").tag("")

                            ForEach(availableProfiles) { profile in
                                Text(profile.fingerprint.id)
                                    .tag(profile.fingerprint.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedProfileID) { _, newValue in
                            guard let selected = availableProfiles.first(where: { $0.fingerprint.id == newValue }) else {
                                return
                            }
                            profile = selected
                        }
                    }

                    Section(header: Text("Adapter")) {
                        InfoRow(title: "Firmware", value: firmware)
                        InfoRow(title: "Description", value: description)
                        InfoRow(title: "Identifier", value: identifier)
                        InfoRow(title: "Voltage", value: voltage)
                        InfoRow(title: "Protocol", value: protocolName)
                        InfoRow(title: "Protocol Number", value: protocolNumber)
                    }

                    Section(header: Text("📘 Standard Commands")) {
                        ForEach(currentProfile.standardCommands.map(\.command), id: \.self) { cmd in
                            CapabilityRow(title: cmd, status: .supported)
                        }
                    }

                    Section(header: Text("🧩 Optional Commands")) {
                        ForEach(currentProfile.optionalCommands.map(\.command), id: \.self) { cmd in
                            CapabilityRow(title: cmd, status: .supported)
                        }
                    }

                    Section(header: Text("🏭 Vendor Commands")) {
                        ForEach(currentProfile.vendorCommands.map(\.command), id: \.self) { cmd in
                            CapabilityRow(title: cmd, status: .supported)
                        }
                    }

                    Section(header: Text("Unsupported Commands")) {
                        ForEach(unsupportedCommands, id: \.self) { cmd in
                            CapabilityRow(title: cmd, status: .unsupported)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("ELM327")
            .task {
                guard !isLoadingProfile else { return }
                isLoadingProfile = true
                loadState = .loading
                defer { isLoadingProfile = false }

                do {
                    availableProfiles = try await ELMProfileStore.shared.loadAll()
                    let fingerprint = try await ELMDiscoveryEngine.shared.readFingerprint(using: ELM327.shared)

                    if let storedProfile = try await ELMProfileStore.shared.load(fingerprint: fingerprint.id) {
                        profile = storedProfile
                        selectedProfileID = storedProfile.fingerprint.id
                        loadState = .loaded
                    } else {
                        profile = nil
                        selectedProfileID = ""
                        loadState = .noProfile
                    }
                } catch {
                    print("Failed to load ELM profile: \(error)")
                    profile = nil
                    loadState = .noProfile
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        discoveryFinished = false
                        discoveryProgress = 0
                        discoveryTitle = "Preparing discovery..."
                        discoveryTask = Task {
                            isDiscovering = true
                            defer {
                                Task { @MainActor in
                                    discoveryFinished = true
                                    isDiscovering = false
                                }
                            }

                            for await event in ELMDiscoveryEngine.shared.discoverWithProgress(using: ELM327.shared) {
                                switch event {
                                case .progress(let progress):
                                    await MainActor.run {
                                        discoveryTitle = progress.title
                                        discoveryProgress = Double(progress.currentStep) / Double(progress.totalSteps)
                                    }

                                case .finished(let discoveredProfile):
                                    let profiles = (try? await ELMProfileStore.shared.loadAll()) ?? []

                                    await MainActor.run {
                                        discoveryProgress = 1
                                        availableProfiles = profiles
                                        profile = discoveredProfile
                                        selectedProfileID = discoveredProfile.fingerprint.id
                                    }
                                }
                            }
                        }
                    } label: {
                        Label(isDiscovering ? "Discovering…" : "Discover",
                              systemImage: isDiscovering ? "hourglass" : "sparkles.rectangle.stack")
                    }
                    .disabled(isDiscovering)
                    .help("Run ELM Discovery")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isDiscovering || discoveryFinished {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.regularMaterial)
                            .shadow(radius: 12)

                        VStack(spacing: 16) {
                            if discoveryFinished {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 34))
                                    .foregroundStyle(.green)

                                Text("Discovery Complete")
                                    .font(.headline)
                            } else {
                                ProgressView(value: discoveryProgress)
                                    .frame(width: 180)

                                Text(discoveryTitle)
                                    .font(.headline)
                                    .multilineTextAlignment(.center)

                                Text("\(Int(discoveryProgress * 100))%")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }

                            Button(discoveryFinished ? "Done" : "Cancel") {
                                if discoveryFinished {
                                    discoveryFinished = false
                                    isDiscovering = false
                                } else {
                                    discoveryTask?.cancel()
                                    isDiscovering = false
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 18)
                    }
                    .frame(width: 240)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.snappy, value: isDiscovering)
            .animation(.snappy, value: discoveryFinished)
        }
    }
}

private struct InfoRow: View {
    let title: String
    let value: String
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private enum CapabilityStatus {
    case supported
    case unsupported
    case unknown
}

private struct CapabilityRow: View {
    let title: String
    let status: CapabilityStatus
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: {
                switch status {
                case .supported: return "checkmark.circle.fill"
                case .unsupported: return "xmark.circle.fill"
                case .unknown: return "questionmark.circle.fill"
                }
            }())
                .foregroundColor({
                    switch status {
                    case .supported: return .green
                    case .unsupported: return .red
                    case .unknown: return .orange
                    }
                }())
                .accessibilityLabel({
                    switch status {
                    case .supported: return "Supported"
                    case .unsupported: return "Unsupported"
                    case .unknown: return "Unknown"
                    }
                }())
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
struct ELMView_Previews: PreviewProvider {
    static var previews: some View {
        ELMView(profile: .empty)
    }
}
#endif
