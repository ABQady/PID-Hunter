//
//  SettingsView.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 28/06/2026.
//
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    private struct BrowserDestination: Identifiable {
        let id = UUID()
        let location: StorageLocation?
    }

    @State private var browserDestination: BrowserDestination?
    
    @Environment(BikeProfileManager.self)
    private var manager
    @ObservedObject private var brute = BruteForceScanner.shared
    @AppStorage("enableDebugLogging")
    private var enableDebugLogging = false

    @AppStorage("debugVerbosity")
    private var debugVerbosity = DebugVerbosity.normal.rawValue

    @AppStorage("verboseCategory.communication") private var verboseCommunication = true
    @AppStorage("verboseCategory.transport") private var verboseTransport = true
    @AppStorage("verboseCategory.assembler") private var verboseAssembler = true
    @AppStorage("verboseCategory.parser") private var verboseParser = true
    @AppStorage("verboseCategory.setup") private var verboseSetup = true
    @AppStorage("verboseCategory.scanner") private var verboseScanner = true
    @AppStorage("verboseCategory.discovery") private var verboseDiscovery = true
    @AppStorage("verboseCategory.persistence") private var verbosePersistence = true
    @AppStorage("verboseCategory.bluetooth") private var verboseBluetooth = true
    @AppStorage("verboseCategory.telemetry") private var verboseTelemetry = true
    @AppStorage("verboseCategory.outcome") private var verboseOutcome = true
    @AppStorage("verboseCategory.lifecycle") private var verboseLifecycle = true
    
    @ObservedObject private var modeDiscovery = ModeDiscovery.shared

    @AppStorage("forceModeSelection")
    private var forceModeSelection = false
    private var availableModes: [OBDMode] {
        if forceModeSelection {
            return OBDMode.discoveryModes
        }
        if !modeDiscovery.supportedModes.isEmpty {
            return modeDiscovery.supportedModes
        }
        return OBDMode.discoveryModes
    }

    @AppStorage("requestTimeout")
    private var requestTimeout = 2.0

    @AppStorage("enableAutoPreflight")
    private var enableAutoPreflight = true

    @AppStorage("maxConsecutiveTimeouts")
    private var maxConsecutiveTimeouts = 15
    
    @AppStorage("selectedSearchEngine")
    private var selectedSearchEngine = SearchEngineType.sequential.rawValue

    @AppStorage("useResponseLatency")
    private var useResponseLatency = true

    @AppStorage("rememberDiscoveries")
    private var rememberDiscoveries = true

    @AppStorage("enableTelemetryLearning")
    private var enableTelemetryLearning = true

    @AppStorage("successWeight")
    private var successWeight = 1000.0

    @AppStorage("latencyWeight")
    private var latencyWeight = 1000.0

    @AppStorage("confidenceWeight")
    private var confidenceWeight = 2.0

    @AppStorage("distanceWeight")
    private var distanceWeight = 1.0

    private var selectedEngine: SearchEngine? {
        SearchEngineCatalog.engine(SearchEngineType(rawValue: selectedSearchEngine) ?? .sequential)
    }

    private var isSmartEngineSelected: Bool {
        selectedEngine?.type == .smart
    }

    @Binding var header: String
    @Binding var selectedMode: OBDMode
    @Binding var startPID: String
    @Binding var endPID: String
    @Binding var delay: Double
    
    struct ExportedFile: Identifiable {
        let id = UUID()
        let url: URL
    }
    
    #if os(iOS)
    @State private var exportedFile: ExportedFile?
    #endif

    // MARK: - Storage

    private struct StorageUsage {
        let applicationSupport: Int64
        let documents: Int64
        let caches: Int64

        var total: Int64 {
            applicationSupport + documents + caches
        }
    }

    private var storageUsage: StorageUsage {
        let fm = FileManager.default

        func folderSize(_ directory: FileManager.SearchPathDirectory) -> Int64 {
            guard let url = try? fm.url(
                for: directory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ) else {
                return 0
            }

            var total: Int64 = 0

            if let enumerator = fm.enumerator(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            ) {
                for case let fileURL as URL in enumerator {
                    if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                       let size = values.fileSize {
                        total += Int64(size)
                    }
                }
            }

            return total
        }

        return StorageUsage(
            applicationSupport: folderSize(.applicationSupportDirectory),
            documents: folderSize(.documentDirectory),
            caches: folderSize(.cachesDirectory)
        )
    }


    // MARK: - Storage Sheet Helper

    private func openStorage(at location: StorageLocation?) {
        browserDestination = BrowserDestination(location: location)
    }

    // MARK: - Export

    private func exportCSV() {
        do {
            let url = try Exporter.export(brute.results)
            #if os(iOS)
            exportedFile = ExportedFile(url: url)
            #endif
        } catch {
            print(error)
        }
    }

    private func exportLog() {
        Task {
            do {
                let url = try await Logger.shared.exportCurrentLog()
#if os(iOS)
                await MainActor.run {
                    exportedFile = ExportedFile(url: url)
                }
#endif
            } catch {
                print(error)
            }
        }
    }

    private var settingsTab: some View {
        ScrollView {
            
            VStack(spacing: 18) {
                
                BikeProfileCard(context: manager.context)
                
                // MARK: Configuration
                VStack(alignment: .leading, spacing: 12) {
                    
                    Text("Scan Configuration")
                        .font(.headline)
                    HStack(alignment: .center){
                        Text("Header")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Picker("Header", selection: $header) {
                            Text("81F111 - ECU ").tag("81F111")
                            Text("80F111 - Common KWP").tag("80F111")
                            Text("82F111 - Extended").tag("82F111")
                        }
                        .pickerStyle(.menu)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        
                        Text("OBD Mode")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        
                        Picker("Mode", selection: $selectedMode) {
                            ForEach(availableModes) { mode in
                                Text("\(mode.title)")
                                    .tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.trailing)
                    }
                    
                    Toggle(isOn: $forceModeSelection) {
                        Label(
                            "Force Mode (Expert)",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                    }
                    .disabled(modeDiscovery.isRunning)
                    .tint(.orange)
                    Divider()
                    
                    if selectedMode.pidRange != nil {
                        Text("PID Range")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Start PID")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                TextField(
                                    "%0\(selectedMode.scanCapability.pidWidth)X",
                                    text: $startPID
                                )
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                            }
                            
                            VStack(alignment: .leading) {
                                Text("End PID")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                TextField(
                                    "%0\(selectedMode.scanCapability.pidWidth)X",
                                    text: $endPID
                                )
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                            }
                        }
                        Divider()
                    }
                    Text("Request Delay: \(Int(delay)) ms")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    
                    Slider(
                        value: $delay,
                        in: 50...1000,
                        step: 10
                    )
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Request Timeout: \(requestTimeout, specifier: "%.1f") s")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        
                        Slider(
                            value: $requestTimeout,
                            in: 0.5...5.0,
                            step: 0.5
                        )
                    }
                    
                    Divider()
                    
                    Stepper(value: $maxConsecutiveTimeouts, in: 1...100) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Max Consecutive Timeouts")
                                .font(.headline)
                            
                            Text("Stop scan after \(maxConsecutiveTimeouts) consecutive request timeouts.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    Toggle(isOn: $enableAutoPreflight) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Auto Preflight", systemImage: "checklist")
                                .font(.headline)
                            
                            Text("Automatically initialize the ELM327 before each scan.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    Toggle(isOn: $enableDebugLogging) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Enable Debug Logging", systemImage: "ladybug.fill")
                                .font(.headline)
                            
                            Text("Show internal parser, assembler and Bluetooth diagnostic messages.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 28)
                        }
                    }
                    
                    if enableDebugLogging {
                        Divider()

                        HStack {
                            Text("Debug Level")
                                .font(.title3)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Picker("Debug Level", selection: $debugVerbosity) {
                                Text("Normal")
                                    .tag(DebugVerbosity.normal.rawValue)
                                Text("Verbose")
                                    .tag(DebugVerbosity.verbose.rawValue)
                            }
                            .pickerStyle(.menu)
                        }

                        Divider()
                        // Enable All Categories toggle
                        Toggle(
                            "Enable All Categories",
                            isOn: Binding(
                                get: {
                                    verboseCommunication &&
                                    verboseTransport &&
                                    verboseAssembler &&
                                    verboseParser &&
                                    verboseSetup &&
                                    verboseScanner &&
                                    verboseDiscovery &&
                                    verbosePersistence &&
                                    verboseBluetooth &&
                                    verboseTelemetry &&
                                    verboseOutcome &&
                                    verboseLifecycle
                                },
                                set: { value in
                                    verboseCommunication = value
                                    verboseTransport = value
                                    verboseAssembler = value
                                    verboseParser = value
                                    verboseSetup = value
                                    verboseScanner = value
                                    verboseDiscovery = value
                                    verbosePersistence = value
                                    verboseBluetooth = value
                                    verboseTelemetry = value
                                    verboseOutcome = value
                                    verboseLifecycle = value
                                }
                            )
                        )
                        // Grouped verbose category toggles
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Communication")
                                .font(.headline)
                            Toggle("Communication", isOn: $verboseCommunication)
                            Toggle("Transport", isOn: $verboseTransport)
                            Toggle("Bluetooth", isOn: $verboseBluetooth)
                            Toggle("Assembler", isOn: $verboseAssembler)
                        }
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Processing")
                                .font(.headline)
                            Toggle("Parser", isOn: $verboseParser)
                            Toggle("Outcome", isOn: $verboseOutcome)
                            Toggle("Telemetry", isOn: $verboseTelemetry)
                        }
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Scanner")
                                .font(.headline)
                            Toggle("Setup", isOn: $verboseSetup)
                            Toggle("Scanner", isOn: $verboseScanner)
                            Toggle("Discovery", isOn: $verboseDiscovery)
                            Toggle("Persistence", isOn: $verbosePersistence)
                            Toggle("Lifecycle", isOn: $verboseLifecycle)
                        }
                    }
                }
                .textFieldStyle(.roundedBorder)
                .padding()
                .background(.thinMaterial)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 18
                    )
                )
                
                //MARK: Search Engine Settings
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack{
                        Text("Search Engine")
                            .font(.headline)
                        Spacer()
                        Picker("Algorithm", selection: $selectedSearchEngine) {
                            ForEach(SearchEngineCatalog.all) { engine in
                                Label(
                                    engine.displayName,
                                    systemImage: engine.icon
                                )
                                .tag(engine.type.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    if let engine = selectedEngine {
                        HStack(alignment: .center){
                            Spacer()
                            Label(engine.description, systemImage: engine.icon)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                    
                    if isSmartEngineSelected {
                        
                        Divider()
                        
                        Toggle("Enable Telemetry Learning", isOn: $enableTelemetryLearning)
                        
                        Group {
                            Text("Success Weight: \(Int(successWeight))")
                            Slider(value: $successWeight, in: 100...3000, step: 50)
                            
                            Text("Latency Weight: \(Int(latencyWeight))")
                            Slider(value: $latencyWeight, in: 100...3000, step: 50)
                            
                            Text("Confidence Weight: \(confidenceWeight, specifier: "%.1f")")
                            Slider(value: $confidenceWeight, in: 0...10, step: 0.5)
                            
                            Text("Distance Weight: \(distanceWeight, specifier: "%.1f")")
                            Slider(value: $distanceWeight, in: 0...10, step: 0.5)
                        }
                        .font(.caption)
                    }
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(
                    RoundedRectangle(cornerRadius: 18)
                )
                
                
                StorageUsageCard(
                    storage: .init(
                        profiles: storageUsage.applicationSupport,
                        logs: storageUsage.documents,
                        cache: storageUsage.caches
                    ),
                    openLocation: { location in
                        switch location {
                        case .profiles:
                            openStorage(at: .applicationSupport)
                        case .logs:
                            openStorage(at: .documents)
                        case .cache:
                            openStorage(at: .caches)
                        }
                    }
                )

                /////////////////////////// MARK: Export
                VStack(alignment: .leading) {
                    HStack(alignment: .center) {
                        Spacer()
                        Button {
                            exportCSV()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.headline.weight(.bold))
                                    .frame(height: 28)

                                Text("Export CSV")
                                    .font(.caption.bold())
                            }

                        }
                        Spacer()
                        Button {
                            exportLog()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "doc.badge.arrow.up")
                                    .font(.headline.weight(.bold))
                                    .frame(height: 28)

                                Text("Export Log")
                                    .font(.caption.bold())
                            }
                        }
                        Spacer()
                        Button {
                            openStorage(at: nil)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "internaldrive.fill")
                                    .font(.headline.weight(.bold))
                                    .frame(height: 28)
                                    .foregroundColor(.accentColor)
                                    .frame(height: 28)

                                Text("App Storage")
                                    .font(.caption.bold())
                            }
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .controlSize(.regular)
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(
                    RoundedRectangle(cornerRadius: 18)
                )
                .sheet(item: $browserDestination) { destination in
                    StorageBrowserView(initialLocation: destination.location)
                }
                .onChange(of: modeDiscovery.supportedModes) { _, modes in
                    guard !forceModeSelection else { return }
                    
                    guard let first = availableModes.first else { return }
                    
                    if !availableModes.contains(selectedMode) {
                        selectedMode = first
                    }
                    if let range = first.pidRange {
                        let width = first.scanCapability.pidWidth
                        startPID = String(format: "%0\(width)X", range.lowerBound)
                        endPID = String(format: "%0\(width)X", range.upperBound)
                    } else {
                        startPID = ""
                        endPID = ""
                    }
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }
    var body: some View {
    #if os(iOS)
        settingsTab
            .sheet(item: $exportedFile) { item in
                ShareSheet(activityItems: [item.url])
            }
    #else
        settingsTab
    #endif
    }
}

