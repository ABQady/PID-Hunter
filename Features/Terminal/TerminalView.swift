//
//  TermialView.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 28/06/2026.
//

import SwiftUI
struct TerminalView: View {
    @ObservedObject private var bt = BluetoothManager.shared
    @ObservedObject private var brute = BruteForceScanner.shared
    @ObservedObject private var stats = ScanStatistics.shared
    @Bindable var viewModel: TerminalViewModel
    @State private var programmaticScroll = false
    @State private var search = ""
    @State private var shouldAutoScroll = true
    @State private var showDisconnectConfirmation = false
    @Binding var selectedMode: OBDMode
    @Binding var header: String
    @Binding var startPID: String
    @Binding var endPID: String
    @State private var manualCommand = ""
    @FocusState private var commandFieldFocused: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }
    
    @inline(__always)
    private var compactStatusTitle: String {
        switch bt.status.title {
        case "Waiting for response...":
            return "Waiting"
        case "Connected":
            return "Connected"
        case "Disconnected":
            return "Offline"
        case let title where title.hasPrefix("Connected"):
            return "Connected"
        default:
            return bt.status.title
        }
    }
    
    private var formattedElapsed: String {
        formatETA(stats.elapsed(at: .now))
    }

    private var formattedETA: String {
        formatETA(stats.eta(at: .now))
    }
    
    @inline(__always)
    private var cleanHeader: String {
        header
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }
    
    public init(
        viewModel: TerminalViewModel,
        selectedMode: Binding<OBDMode>,
        header: Binding<String>,
        startPID: Binding<String>,
        endPID: Binding<String>
    ) {
        self.viewModel = viewModel
        _selectedMode = selectedMode
        _header = header
        _startPID = startPID
        _endPID = endPID
    }
    
    private func jumpToLive(proxy: ScrollViewProxy) {
        guard let last = viewModel.lines.last else { return }

        shouldAutoScroll = true
        programmaticScroll = true

        withAnimation(nil) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            programmaticScroll = false
        }
    }
    
    private var launchScan: () -> Void {
        {
            ScanLauncher.shared.start(
                bt: bt,
                brute: brute,
                stats: stats,
                mode: selectedMode,
                header: header,
                startPID: startPID,
                endPID: endPID,
                cleanHeader: cleanHeader
            ) {
                shouldAutoScroll = true
                programmaticScroll = true

                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(100))
                    programmaticScroll = false
                }
            }
        }
    }
    
    
    private var terminalTab: some View {
        ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 18) {
                    //MARK: Status Card
                    StatusCard(
                        bt: bt,
                        selectedMode: selectedMode,
                        header: header,
                        showDisconnectConfirmation: $showDisconnectConfirmation,
                        isCompact: isCompact
                    )
                    
                    
                    ProgressCard(
                        progress: stats.progressFraction,
                        currentRequests: stats.requestsSent,
                        totalRequests: stats.totalRequests,
                        elapsed: formattedElapsed,
                        eta: formattedETA,
                        successRate: brute.statistics.successRate,
                        averageLatency: brute.statistics.averageLatency,
                        isScanning: brute.scanStatus.isScanning,
                        isCompleted: stats.requestsSent >= stats.totalRequests,
                        hasResumePoint: brute.hasResumePoint
                    )
                    
                    ActionBar(
                        isConnected: bt.isConnected,
                        isScanning: brute.scanStatus.isScanning,
                        hasResumePoint: brute.hasResumePoint,
                        hasLines: !viewModel.lines.isEmpty,
                        isCompact: isCompact,
                        onClear: {
                            viewModel.clear()
                        },
                        onScan: launchScan,
                        onStop: {
                            brute.stop()
                        },
                        onResume: launchScan,
                        onTestECU: {
                            Task {
                                await ECUTester.shared.run(header: cleanHeader)
                            }
                        },
                        onDiscoverModes: {
                            Task {
                                await ModeDiscovery.shared.discover()
                            }
                        }
                    )
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ScrollViewReader { proxy in
                            VStack(spacing: 8) {
                                TerminalHeader(
                                    title: "Terminal",
                                    status: isCompact ? compactStatusTitle : bt.status.title,
                                    found: brute.scanStatus.successCount,
                                    successRate: brute.statistics.successRate,
                                    averageLatency: brute.statistics.averageLatency,
                                    txCount: bt.txCount,
                                    rxCount: bt.rxCount,
                                    isCompact: isCompact,
                                    onJumpToLive: {
                                        jumpToLive(proxy: proxy)
                                    }
                                )
                                
                                TerminalLog(
                                    lines: viewModel.lines,
                                    isCompact: isCompact
                                )
                                .simultaneousGesture(
                                    DragGesture()
                                        .onChanged { _ in
                                            shouldAutoScroll = false
                                        }
                                )
                                .onScrollPhaseChange { _, phase in
                                    guard !programmaticScroll else { return }

                                    if phase == .interacting {
                                        shouldAutoScroll = false
                                    }
                                }
                                
                                
                            }
                                .onChange(of: viewModel.lines.count) { _, _ in
                                    guard shouldAutoScroll,
                                          let last = viewModel.lines.last else {
                                        return
                                    }
                                    Task { @MainActor in
                                        withAnimation(nil) {
                                            proxy.scrollTo(last.id, anchor: .bottom)
                                        }
                                    }
                                }
                        }
                        ManualCommandBar(
                            manualCommand: $manualCommand,
                            commandFieldFocused: $commandFieldFocused,
                            send: {
                                ManualCommandSender.shared.send(
                                    bluetoothManager: bt,
                                    manualCommand: &manualCommand
                                )
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity,
                       alignment: .top)
                .layoutPriority(1)
            }
            .scrollDismissesKeyboard(.interactively)
            .frame(maxWidth: .infinity, alignment: .top)
            .padding()
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    commandFieldFocused = false
                }
            )
        }
    
    

    // MARK: - Formatting
    @inline(__always)
    private func formatETA(_ seconds: TimeInterval) -> String {
        
        guard seconds > 0 else {
            return "--:--"
        }
        
        let totalSeconds = max(0, Int(seconds.rounded(.down)))
        
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        }
        
        return String(format: "%02d:%02d", minutes, secs)
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    var body: some View {
        terminalTab
    }
}

// Helper for conditional modifier
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
