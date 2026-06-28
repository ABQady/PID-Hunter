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

    @Binding var header: String
    @Binding var selectedMode: Int
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
                        Text("01").tag(1)
                        Text("21").tag(21)
                        Text("22").tag(22)
                    }
                    .pickerStyle(.segmented)
                    
                    Text("PID Range")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Start PID")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            TextField("0000", text: $startPID)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                        }
                        
                        VStack(alignment: .leading) {
                            Text("End PID")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            TextField("FFFF", text: $endPID)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
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
                }
                .textFieldStyle(.roundedBorder)
                .padding()
                .background(.thinMaterial)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 18
                    )
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
