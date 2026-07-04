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
    let hasResumePoint: Bool
    let hasLines: Bool
    let isCompact: Bool

    let onClear: () -> Void
    let onScan: () -> Void
    let onStop: () -> Void
    let onResume: () -> Void
    let onTestECU: () -> Void
    let onDiscoverModes: () -> Void

    var body: some View {
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
                Button(role: .destructive) {
                    onScan()
                } label: {
                    Label("Scan",
                          systemImage: "dot.radiowaves.up.forward")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isConnected || isScanning)
                
                Button(role: .destructive)
                {
                    onStop()
                } label: {
                    Label("Stop",systemImage:"stop.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isScanning)
                Button {
                    onResume()
                }
                label: {
                    Label("Resume",systemImage: "arrow.clockwise.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isScanning || !hasResumePoint)
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
