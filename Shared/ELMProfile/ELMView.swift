//
//  ELMView.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 17/07/2026.
//

import SwiftUI

struct ELMView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var profile: ELMProfile
    init(profile: ELMProfile) {
        _profile = State(initialValue: profile)
    }
    @State private var isDiscovering = false

    private var firmware: String {
        profile.firmware ?? ""
    }
    private var description: String {
        profile.deviceDescription ?? ""
    }
    private var identifier: String {
        profile.deviceIdentifier ?? ""
    }
    private var voltage: String {
        if let voltageValue = profile.voltage {
            return String(format: "%.1f V", voltageValue)
        } else {
            return ""
        }
    }
    private var protocolName: String {
        profile.protocolDescription ?? ""
    }
    private var protocolNumber: String {
        profile.protocolNumber ?? ""
    }
    private var supportedCommands: [String] {
        profile.supportedCommands.map { $0.command }
    }
    private var unsupportedCommands: [String] {
        profile.unsupportedCommands.map { $0.command }
    }

    var body: some View {
        NavigationStack {
            List {
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
                    ProgressView(value: profile.supportRate)
                        .tint(.green)
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                    HStack {
                        Spacer()
                        VStack {
                            Text("\(profile.supportedCommands.count)")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text("Supported")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack {
                            Text("\(profile.unsupportedCommands.count)")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text("Unsupported")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack {
                            Text("\(Int(profile.supportRate * 100))%")
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

                Section(header: Text("Adapter")) {
                    InfoRow(title: "Firmware", value: firmware)
                    InfoRow(title: "Description", value: description)
                    InfoRow(title: "Identifier", value: identifier)
                    InfoRow(title: "Voltage", value: voltage)
                    InfoRow(title: "Protocol", value: protocolName)
                    InfoRow(title: "Protocol Number", value: protocolNumber)
                }

                Section(header: Text("📘 Standard Commands")) {
                    ForEach(profile.standardCommands.map(\.command), id: \.self) { cmd in
                        CapabilityRow(title: cmd, status: .supported)
                    }
                }

                Section(header: Text("🧩 Optional Commands")) {
                    ForEach(profile.optionalCommands.map(\.command), id: \.self) { cmd in
                        CapabilityRow(title: cmd, status: .supported)
                    }
                }

                Section(header: Text("🏭 Vendor Commands")) {
                    ForEach(profile.vendorCommands.map(\.command), id: \.self) { cmd in
                        CapabilityRow(title: cmd, status: .supported)
                    }
                }

                Section(header: Text("Unsupported Commands")) {
                    ForEach(unsupportedCommands, id: \.self) { cmd in
                        CapabilityRow(title: cmd, status: .unsupported)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("ELM327")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            isDiscovering = true
                            defer { isDiscovering = false }
                            let discoveredProfile = await ELMDiscoveryEngine.shared.discover(using: ELM327.shared)
                            await MainActor.run {
                                profile = discoveredProfile
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
