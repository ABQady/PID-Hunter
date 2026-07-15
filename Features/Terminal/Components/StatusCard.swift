//
//  StatusCard.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 04/07/2026.
//
import SwiftUI

struct StatusCard: View {
    @ObservedObject var bt: BluetoothManager
    let selectedMode: OBDMode
    let header: String
    @Binding var showDisconnectConfirmation: Bool
    let isCompact: Bool
    let onRestartECU: () -> Void

    @State private var showRestartConfirmation = false

    var body: some View {
        HStack {
            Circle()
                .fill(bt.isConnected ? Color.green: Color.red)
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(bt.isConnected ? "Connected" : "Disconnected")
                if bt.isConnected {
                    Text(selectedMode.title)
                        .font(.caption.monospaced())
                    Text(header)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            HStack(spacing: 6) {
                Button {
                    if bt.isScanning {
                        showRestartConfirmation = true
                    } else {
                        onRestartECU()
                    }
                } label: {
                    Image(systemName: "arrow.trianglehead.clockwise")
                }
                .buttonStyle(.bordered)
                .labelStyle(.iconOnly)
                .disabled(!bt.isConnected)
                .confirmationDialog(
                    "Restart ECU?",
                    isPresented: $showRestartConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Restart ECU", role: .destructive) {
                        onRestartECU()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will restart the ECU and interrupt the current scan. Continue?")
                }

                Button {
                    if bt.isConnected {
                        showDisconnectConfirmation = true
                    } else {
                        bt.startScan()
                    }
                } label: {
                    Label(
                        bt.isConnected ? "Disconnect" : "Scan BLE",
                        systemImage: bt.isConnected ? "bolt.horizontal.circle.fill" : "dot.radiowaves.left.and.right"
                    )
                }
                .buttonStyle(.bordered)
                .disabled(!bt.isConnected && bt.isScanning)
                .confirmationDialog(
                    "Disconnect from ELM327?",
                    isPresented: $showDisconnectConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Disconnect", role: .destructive) {
                        bt.disconnect()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Are you sure you want to disconnect from the connected BLE adapter?")
                }
                .if(isCompact) { view in
                    view.labelStyle(.iconOnly)
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
