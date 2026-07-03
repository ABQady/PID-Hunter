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
    @ObservedObject private var brute = BruteForceScanner.shared
    @AppStorage("enableDebugLogging")
    private var enableDebugLogging = false

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

    private var settingsTab: some View {
        ScrollView {
            
            VStack(spacing: 18) {
                
                // MARK: Configuration
                VStack(alignment: .leading, spacing: 12) {
                    
                    Text("Configuration")
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
                    Text("OBD Mode")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Picker("Mode", selection: $selectedMode) {
                        ForEach(OBDMode.supportedScanModes) { mode in
                            Text(mode.rawValue)
                                .help(mode.title)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Label(selectedMode.title, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if selectedMode.pidDigits == 4 {
                        Text("PID Range")
                            .font(.title3)
                            .foregroundStyle(.secondary)

                        HStack {
                            VStack(alignment: .leading) {
                                Text("Start PID")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                TextField("%0\(selectedMode.pidDigits)X", text: $startPID)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                            }

                            VStack(alignment: .leading) {
                                Text("End PID")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                TextField("%0\(selectedMode.pidDigits)X", text: $endPID)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                            }
                        }
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

                    Text("Search Engine")
                        .font(.headline)

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

                    if selectedSearchEngine == SearchEngineType.smart.rawValue {

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

                    Divider()

//                    Toggle(isOn: $useResponseLatency) {
//
//                        VStack(alignment: .leading) {
//
//                            Label(
//                                "Use Response Latency",
//                                systemImage: "timer"
//                            )
//
//                            Text("Allow adaptive engines to prioritize fast ECU responses.")
//                                .font(.caption)
//                                .foregroundStyle(.secondary)
//
//                        }
//                    }
//
//                    Divider()
//
//                    Toggle(isOn: $rememberDiscoveries) {
//
//                        VStack(alignment: .leading) {
//
//                            Label(
//                                "Remember Previous Discoveries",
//                                systemImage: "brain.head.profile"
//                            )
//
//                            Text("Reuse discovered PIDs and learned patterns between scans.")
//                                .font(.caption)
//                                .foregroundStyle(.secondary)
//
//                        }
//                    }

                }
                .padding()
                .background(.thinMaterial)
                .clipShape(
                    RoundedRectangle(cornerRadius: 18)
                )
                
                //MARK: Statistics
                
                VStack(alignment: .leading, spacing: 12) {

                    Text("Search Statistics")
                        .font(.headline)

                    HStack {

                        statistic(
                            title: "Requests",
                            value: "\(brute.statistics.requestsSent)"
                        )

                        Spacer()

                        statistic(
                            title: "Success",
                            value: String(
                                format: "%.1f%%",
                                brute.statistics.successRate * 100
                            )
                        )

                    }

                    HStack {
                        statistic(
                            title: "Latency",
                            value: String(
                                format: "%.0f ms",
                                brute.statistics.averageLatency * 1000
                            )
                        )

                        Spacer()
                        statistic(
                            title: "Hits",
                            value: "\(brute.scanStatus.successCount)"
                        )

                    }

                }
                .padding()
                .background(.thinMaterial)
                .clipShape(
                    RoundedRectangle(cornerRadius: 18)
                )
                
                /////////////////////////// MARK: Export
                HStack(alignment: .center) {
                #if os(iOS)
                    Button("Export CSV") {
                        do {
                            let url = try CSVExporter.export(brute.results)
                            exportedFile = ExportedFile(url: url)
                        } catch {
                            print(error)
                        }
                    }

                    Button("Export Log") {
                        do {
                            let url = try Logger.shared.saveLog()
                            exportedFile = ExportedFile(url: url)
                        } catch {
                            print(error)
                        }
                    }
                #else
                    Button("Export CSV") {
                        do {
                            _ = try CSVExporter.export(brute.results)
                        } catch {
                            print(error)
                        }
                    }

                    Button("Export Log") {
                        do {
                            _ = try Logger.shared.saveLog()
                        } catch {
                            print(error)
                        }
                    }
                #endif
                }
                .buttonStyle(.bordered)
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18)
                )
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

@ViewBuilder
private func statistic(
    title: String,
    value: String
) -> some View {

    VStack(alignment: .leading, spacing: 2) {

        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)

        Text(value)
            .font(.headline)
    }
}
