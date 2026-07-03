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
    @ObservedObject private var logger = Logger.shared
    @ObservedObject private var stats = ScanStatistics.shared

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

    // Progress fraction for progress bar and percentage
    private var progressFraction: Double {
        guard stats.totalRequests > 0 else { return 0 }
        return min(max(Double(stats.requestsSent) / Double(stats.totalRequests), 0), 1)
    }

    @inline(__always)
    private var cleanHeader: String {
        header
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    public init(
        selectedMode: Binding<OBDMode>,
        header: Binding<String>,
        startPID: Binding<String>,
        endPID: Binding<String>
    ) {
        _selectedMode = selectedMode
        _header = header
        _startPID = startPID
        _endPID = endPID
    }

    // MARK: - Sections
    private var terminalTab: some View {
        VStack(spacing: 18) {
            // MARK: Status
            HStack {
                Circle()
                    .fill(bt.isConnected ? Color.green: Color.red)
                    .frame(width: 12, height: 12)
                Text(bt.isConnected ? "Connected" : "Disconnected")
                Spacer()
                if bt.isConnected {
                    Text("Mode: \(selectedMode)")
                        .monospacedDigit()
                    Spacer()
                    Text("Header: \(header)")
                        .font(.system(.body, design: .monospaced))
                }
                Spacer()
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
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            
            // MARK: Progress
            VStack(alignment: .leading) {
                Text("Progress")
                    .font(.headline)
                ProgressView(value: progressFraction)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: .infinity)
                HStack(alignment: .center, spacing: 4) {
                    Spacer()
                    Text("\(Int(progressFraction * 100))%")
                    Spacer()
                    HStack {
                        Text("\(stats.requestsSent)")
                            .bold()
                        Text("/")
                        Text("\(stats.totalRequests) Requests")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        HStack {
                            Spacer()
                            Text("Elapsed: \(formatETA(stats.elapsed(at: context.date)))")

                            if stats.finishedAt != nil {
                                Text("Completed in \(formatETA(stats.elapsed(at: context.date))) ✅")
                            } else if !brute.scanStatus.isScanning {
                                Text("ETA: --:--")
                            } else if stats.requestsSent < 10 {
                                Text("ETA: Calculating...")
                            } else {
                                Text("ETA: \(formatETA(stats.eta(at: context.date)))")
                            }
                        }
                    }
                    Spacer()
                }
                .font(.system(.caption, design: .monospaced))
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            if brute.hasResumePoint && !brute.scanStatus.isScanning {
                Text("Resume available")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        // MARK: Actions - single horizontal HStack
            HStack(alignment: .center, spacing: 10) {
                Button {
                    Logger.shared.clear()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(logger.lines.isEmpty)
                
                Spacer()
                Button(role: .destructive) {
                    guard bt.isConnected else {
                        Logger.shared.info("Connect to ELM first")
                        return
                    }
                    brute.startFresh()
                    Logger.shared.info("🗑️ Starting fresh scan")
                    startPIDScan()
                } label: {
                    Label("Scan", systemImage: "dot.radiowaves.up.forward")
                }
                .buttonStyle(.borderedProminent)
                
                Button(role: .destructive)
                {
                    brute.stop()
                } label: {
                    Label("Stop",systemImage:"stop.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!brute.scanStatus.isScanning)
                Button {
                    guard brute.hasResumePoint else {
                        Logger.shared.info("No resume point available")
                        return
                    }
                    startPIDScan()
                }
                label: {
                    Label("Resume",systemImage: "arrow.clockwise.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(brute.scanStatus.isScanning || !brute.hasResumePoint)
                Spacer()
                Button {
                    Task {
                        await ECUTester.shared.run(header: cleanHeader)
                    }
                } label: {
                    Label("Test ECU", systemImage: "stethoscope")
                }
                .buttonStyle(.bordered)
                
                Button {
                    Task {
                        await ModeDiscovery.shared.discover()
                    }
                } label: {
                    Label("Discover Modes", systemImage: "dot.scope")
                }
                .buttonStyle(.bordered)
            }
            .controlSize(horizontalSizeClass == .compact ? .small : .regular)
            .if(isCompact) { view in
                view.labelStyle(.iconOnly)
            }
            .if(isCompact) { view in
                view.font(.title3)
            }
            
            
            // MARK: Live Log
            VStack(alignment: .leading) {
                ScrollViewReader { proxy in
                    HStack(spacing: isCompact ? 4 : 16) {
                        Text("Terminal")
                            .font(isCompact ? .body.weight(.semibold) : .headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(width: isCompact ? 58 : 70, alignment: .leading)
                            .padding(.leading, isCompact ? -10 : 0)
                            .layoutPriority(2)
                        if !isCompact {
                            Spacer()
                        }
                        Text(isCompact ? compactStatusTitle : bt.status.title)
                            .font(isCompact ? .caption2 : .headline)
                            .lineLimit(1)
                            .allowsTightening(true)
                            .minimumScaleFactor(0.35)
                            .layoutPriority(10)

                        if !isCompact {
                            Spacer()
                        }

                        Text(isCompact ? "F: \(brute.scanStatus.successCount)" : "Found: \(brute.scanStatus.successCount)")
                            .font(isCompact ? .caption2.monospacedDigit() : .headline)
                            .fixedSize()

                        Text(String(format: isCompact ? "%.0f%%" : "%.0f%%", brute.statistics.successRate * 100))
                            .font(isCompact ? .caption2.monospacedDigit() : .headline)
                            .foregroundStyle(.secondary)
                            .fixedSize()

                        if !isCompact {
                            Spacer()
                        }

                        Text(
                            isCompact
                            ? String(format: "%.0fms %d/%d", brute.statistics.averageLatency * 1000, bt.txCount, bt.rxCount)
                            : String(format: "%.0f ms • TX %d • RX %d", brute.statistics.averageLatency * 1000, bt.txCount, bt.rxCount)
                        )
                        .font(isCompact ? .caption2.monospacedDigit() : .headline)
                        .foregroundStyle(.secondary)
                        .fixedSize()

                        if !isCompact {
                            Spacer()
                        }

                        Button {
                            shouldAutoScroll = true
                            programmaticScroll = true

                            if let last = logger.lines.indices.last {
                                withAnimation(.linear(duration: 0.05)) {
                                    proxy.scrollTo(last, anchor: .bottom)
                                }
                            }
                            // Reset programmaticScroll after animation completes using Task
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(100))
                                programmaticScroll = false
                            }
                        } label: {
                            if isCompact {
                                Image(systemName: "arrow.down.circle.fill")
                            } else {
                                Text("▼ Live")
                            }
                        }
                        .font(isCompact ? .caption : .body)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .fixedSize()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding()
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(logger.lines.enumerated()), id: \.element.id) { index, line in
                                Text(line.text)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(line.color)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(index)
                            }
                        }
                        .padding()
                        .background(.black.opacity(0.15))
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 18
                            )
                        )
                        .contentShape(Rectangle())
                    }
                    .scrollDismissesKeyboard(.interactively)
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onChange(of: shouldAutoScroll) { _, newValue in
                        // Removed debug print
                    }
                    .onChange(of: logger.lines.count) { _, _ in
                        guard shouldAutoScroll,
                              let last = logger.lines.indices.last else {
                            return
                        }
                        Task { @MainActor in
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        TextField("Manual command", text: $manualCommand)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .onSubmit(sendManualCommand)
                            .focused($commandFieldFocused)
                            .submitLabel(.send)

                        Button("Send") {
                            sendManualCommand()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(
                            manualCommand
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .isEmpty
                        )
                    }
                    .padding()
                    .onTapGesture {
                        commandFieldFocused = false
                    }
                }
            }
            .frame(maxWidth: .infinity,
                   maxHeight: .infinity,
                   alignment: .top)
            .background(.black.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity,
               maxHeight: .infinity,
               alignment: .top)
        .padding()
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                commandFieldFocused = false
            }
        )
    }
    
    // MARK: - Commands
    private func sendManualCommand() {
        guard bt.isConnected else {
            Logger.shared.info("Connect to ELM first")
            return
        }
        let normalizedCommand = manualCommand
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !normalizedCommand.isEmpty else {
            return
        }
        Logger.shared.tx(normalizedCommand)
        ELM327.shared.send(normalizedCommand)
        manualCommand = ""
    }

    // MARK: - Scan
    private func startPIDScan()
    {
        guard bt.isConnected else {
            Logger.shared.info("Connect to ELM first")
            return
        }
        if !brute.hasResumePoint {
            Logger.shared.clear()
        }

        let headerValue = cleanHeader

        guard headerValue.count == 6,
              headerValue.allSatisfy({ $0.isHexDigit }) else {
            Logger.shared.info("Invalid Header")
            return
        }
        brute.headers = [headerValue]
        shouldAutoScroll = true
        programmaticScroll = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            programmaticScroll = false
        }

        Task {
            let ok = await Preflight.shared.run(header: headerValue)

            guard ok else {
                Logger.shared.error("❌ Preflight Failed")
                return
            }

            if selectedMode.pidDigits == 4 {
                let startText = startPID
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .uppercased()

                let endText = endPID
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .uppercased()

                guard let start = UInt16(startText, radix: 16),
                      let end = UInt16(endText, radix: 16) else {
                    Logger.shared.info("Invalid PID range")
                    return
                }

                guard start <= end else {
                    Logger.shared.info("Start PID must be <= End PID")
                    return
                }

                brute.scan(
                    mode: selectedMode,
                    startPID: start,
                    endPID: end
                )
            } else {
                brute.scan(mode: selectedMode)
            }
        }
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
