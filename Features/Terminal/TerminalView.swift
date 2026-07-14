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
    
    private func launchScan() {
        ScanLauncher.shared.start(
            bt: bt,
            brute: brute,
            mode: selectedMode,
            startPID: startPID,
            endPID: endPID,
            cleanHeader: cleanHeader,
            onPrepareUI: {
                shouldAutoScroll = true
                programmaticScroll = true
            }
        )
        
        shouldAutoScroll = true
        programmaticScroll = true

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            programmaticScroll = false
        }
    }
    
    private var terminalTab: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: isCompact ? 8 : 16) {
                    //MARK: Status Card
                    StatusCard(
                        bt: bt,
                        selectedMode: selectedMode,
                        header: header,
                        showDisconnectConfirmation: $showDisconnectConfirmation,
                        isCompact: isCompact
                    )
                    
                    ProgressCard(
                        stats: stats,
                        successRate: brute.statistics.successRate,
                        averageLatency: brute.statistics.averageLatency,
                        isScanning: brute.scanStatus.isScanning,
                        isCompleted: stats.finishedAt != nil,
                        hasResumePoint: brute.hasResumePoint,
                        currentMode: selectedMode
                    )
                    
                    ActionBar(
                        isConnected: bt.isConnected,
                        isScanning: brute.scanStatus.isScanning,
                        resumeMetadata:
                            ScanPersistence.shared.hasResumePoint
                                ? ScanPersistence.shared.loadResumeMetadata()
                                : nil,
                        hasLines: !viewModel.lines.isEmpty,
                        isCompact: isCompact,
                        onClear: {
                            bt.resetTrafficCounters()
                            viewModel.clear()
                        },
                        onScan: {
                            bt.resetTrafficCounters()
                            launchScan()
                        },
                        onStop: {
                            brute.stop()
                        },
                        onResume: {
                            launchScan()
                        },
                        onTestECU: {
                            Task {
                                await ECUTester.shared.run(header: cleanHeader)
                            }
                        },
                        onDiscoverModes: {
                            Task {
                                await ModeDiscovery.shared.discover()
                            }
                        },
                        onDiscoverHeaders: {
                            Task {
                                await HeaderDiscovery.shared.discover()
                            }
                        }
                    )
                    
                    VStack(alignment: .leading) {
                        ScrollViewReader { proxy in
                            VStack(spacing: 2) {
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
