//
//  ActionBar.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 04/07/2026.
//
import SwiftUI

private struct ActionBarButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: configuration.trigger) {
            configuration.label
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.bordered)
    }
}

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
    let onDiscoverDevices: () -> Void

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
                .buttonStyle(ActionBarButtonStyle())
                .disabled(!hasLines)
                Spacer()
                // A new scan always starts a brand-new scan session.
                // The scan pipeline is responsible for resetting all runtime state
                // (statistics, timers, discoveries, counters, telemetry, resume state, etc.)
                // and then reading the current Header / Mode / PID range from Settings.
                // ActionBar intentionally delegates all of that work through onScan().
                // Resume remains a separate action.
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
                .buttonStyle(ActionBarButtonStyle())
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
                .buttonStyle(ActionBarButtonStyle())
                .disabled(!isScanning)
                
                Spacer()
                
                Button {
                    onDiscoverModes()
                } label: {
                    Label("Discover Modes", systemImage: "dot.scope")
                }
                .buttonStyle(ActionBarButtonStyle())

                Button {
                    onDiscoverDevices()
                } label: {
                    Label("Discover Devices", systemImage: "point.3.connected.trianglepath.dotted")
                }
                .buttonStyle(ActionBarButtonStyle())
            }
            .controlSize(
                isCompact ? .small : .regular
            )
            .buttonBorderShape(.capsule)
            .if(isCompact) {
                $0.labelStyle(.iconOnly)
            }
            .if(isCompact) {
                $0.font(.title3)
            }
            
        }
    }
}
