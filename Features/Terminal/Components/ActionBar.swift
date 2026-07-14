//
//  ActionBar.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 04/07/2026.
//
import SwiftUI

struct ActionBar: View {

    let isConnected: Bool
    let isScanning: Bool
    let resumeMetadata: ScanPersistence.ResumeMetadata?
    let hasLines: Bool
    let isCompact: Bool

    let onClear: () -> Void
    let onScan: () -> Void
    let onStop: () -> Void
    let onResume: () -> Void
    let onTestECU: () -> Void
    let onDiscoverModes: () -> Void
    let onDiscoverHeaders: () -> Void

    @State private var showStartFreshConfirmation = false

    var body: some View {
        VStack{
            HStack{
                if let session = resumeMetadata {
                    
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 8) {
                            
                            LabeledContent("Header") {
                                Text(session.header)
                                    .monospaced()
                            }
                            
                            LabeledContent("Mode") {
                                Text(session.mode?.rawValue ?? "Unknown")
                                    .monospaced()
                            }
                            
                            LabeledContent("Last PID") {
                                Text(String(format: "%04X", session.currentPID))
                                    .monospaced()
                            }
                            
                            Button {
                                onResume()
                            } label: {
                                Label("Resume",
                                      systemImage: "arrow.clockwise.circle.fill")
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!isConnected || isScanning)
                            
                        }
                        .padding()
                        
                    } label: {
                        Label("Resume Available",
                              systemImage: "arrow.clockwise.circle")
                    }
                }
            } .padding(.horizontal)
            HStack(alignment: .center, spacing: 10) {
                Button {
                    onClear()
                } label: {
                    Label("Clear",
                          systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(!hasLines)
                Spacer()
                // Scan and Resume are mutually exclusive to avoid accidentally starting a fresh scan over a resumable session.
                Button(role: .destructive) {
                    if resumeMetadata != nil {
                        showStartFreshConfirmation = true
                    } else {
                        onScan()
                    }
                } label: {
                    Label(
                        resumeMetadata != nil ? "New Scan" : "Scan",
                        systemImage: resumeMetadata != nil
                            ? "arrow.counterclockwise.circle.fill"
                            : "dot.radiowaves.up.forward"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isConnected || isScanning)
                .confirmationDialog(
                    "Start a new scan from the beginning?",
                    isPresented: $showStartFreshConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Start New Scan", role: .destructive) {
                        onScan()
                    }

                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("A resumable scan is available. Starting a new scan will discard the saved progress. Are you sure you want to start from the beginning?")
                }
                
                Button(role: .destructive)
                {
                    onStop()
                } label: {
                    Label("Stop",systemImage:"stop.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isScanning)
                
                Spacer()
                Button {
                    onTestECU()
                } label: {
                    Label("Test ECU", systemImage: "stethoscope")
                }
                .buttonStyle(.bordered)
                
                Button {
                    onDiscoverModes()
                } label: {
                    Label("Discover Modes", systemImage: "dot.scope")
                }
                .buttonStyle(.bordered)

                Button {
                    onDiscoverHeaders()
                } label: {
                    Label("Discover Headers", systemImage: "point.3.connected.trianglepath.dotted")
                }
                .buttonStyle(.bordered)
            }
            .controlSize(
                isCompact ? .small : .regular
            )
            .if(isCompact) {
                $0.labelStyle(.iconOnly)
            }
            .if(isCompact) {
                $0.font(.title3)
            }
            
        }
    }
}
