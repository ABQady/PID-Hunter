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
    @Binding var selectedMode: OBDMode
    @Binding var header: String
    @Binding var startPID: String
    @Binding var endPID: String
    @State private var manualCommand = ""

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
    
    private var terminalTab: some View {
        
        VStack(spacing: 18) {
            ViewThatFits(in: .horizontal) {
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
                    bt.startScan()
                } label: {
                    Label("Scan BLE", systemImage: "dot.radiowaves.left.and.right")
                }
                .buttonStyle(.bordered)
                .disabled(bt.isScanning)
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            // MARK: Progress
            VStack(alignment: .leading) {
                Text("Progress")
                    .font(.headline)
                ProgressView(
                    value: brute.scanStatus.progress
                )
                HStack(alignment: .center, spacing: 4) {
                    Spacer()
                    Text(
                        "\(Int(brute.scanStatus.progress * 100))% • \(brute.scanStatus.currentRequest)"
                    )
                    Spacer()
                    HStack {
                        Text("\(stats.requestsSent)")
                            .bold()
                        Text("/")
                        Text("\(stats.totalRequests) Requests")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        HStack(alignment: .center, spacing: 2) {
                            Spacer()
                            Text("Elapsed: \(formatETA(stats.elapsed))")
                                .foregroundStyle(.secondary)
                            Spacer()
                            if !brute.scanStatus.isScanning {
                                Text("ETA: --:--")
                                    .foregroundStyle(.secondary)
                            } else if stats.finishedAt != nil {
                                Text("Completed in \(formatETA(stats.elapsed)) ✅")
                                    .foregroundStyle(.green)
                            } else if stats.requestsSent < 10 {
                                Text("ETA: Calculating...")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("ETA: \(formatETA(stats.eta))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Spacer()
                }
                .font(.system(.caption, design: .monospaced))
                .font(
                    .system(
                        .caption,
                        design: .monospaced
                    )
                )
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            if brute.hasResumePoint {

                Text("Resume available")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            
/////////////////// MARK: Actions
            
            }
            // MARK: Actions - single horizontal HStack
            HStack(alignment: .center, spacing: 10) {
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
                    startPIDScan()
                }
                label: {
                    Label("Resume",systemImage: "arrow.clockwise.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(brute.scanStatus.isScanning)
                Spacer()
                Button {
                    Task {
                        let cleanHeader = header
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .uppercased()
                        
                        await ECUTester.shared.run(header: cleanHeader)
                    }
                } label: {
                    Label("Test ECU", systemImage: "stethoscope")
                }
                .buttonStyle(.bordered)
            }
            
            
            // MARK: Live Log
            VStack(alignment: .leading) {
                ScrollViewReader { proxy in
                    HStack {
                        Text("Terminal")
                            .font(.headline)
                        Spacer()
                        
                        Text(bt.status.title)
                            .font(.headline)
                        
                        Spacer()
                        
                        Text("Found: \(brute.scanStatus.successCount)")
                            .font(.headline)
                        
                        Spacer()
                        
                        Text("TX \(bt.txCount) • RX \(bt.rxCount)")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Button("▼ Live") {
                            shouldAutoScroll = true
                            programmaticScroll = true
                            
                            if let last = logger.lines.indices.last {
                                withAnimation(.linear(duration: 0.05)) {
                                    proxy.scrollTo(last, anchor: .bottom)
                                }
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                programmaticScroll = false
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding()
                    ScrollView {
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
                    }
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 0)
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
                        print("AutoScroll =", newValue)
                    }
                    .onChange(of: logger.lines.count) { _, _ in
                        guard shouldAutoScroll,
                              let last = logger.lines.indices.last else {
                            return
                        }
                        
                        DispatchQueue.main.async {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        TextField("Manual command", text: $manualCommand)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .onSubmit(sendManualCommand)

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
    }
    
    // MARK: - Helpers
    private func sendManualCommand() {
        let command = manualCommand
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !command.isEmpty else {
            return
        }
        Logger.shared.tx(command)
        ELM327.shared.send(command)
        manualCommand = ""
    }
    
    private func startPIDScan()
    {
        guard bt.isConnected else {
            Logger.shared.info("Connect to ELM first")
            return
        }
        Logger.shared.clear()
        RequestResponseMatcher.shared.clear()

        let cleanHeader = header
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard cleanHeader.count == 6,
              cleanHeader.allSatisfy({ $0.isHexDigit }) else {
            Logger.shared.info("Invalid Header")
            return
        }
        brute.headers = [cleanHeader]
        shouldAutoScroll = true

        Task {
            let ok = await Preflight.shared.run(header: cleanHeader)

            guard ok else {
                Logger.shared.info("❌ Preflight Failed")
                return
            }

            ScanStatistics.shared.start()

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
    private func formatETA(_ seconds: TimeInterval) -> String {

        guard seconds > 0 else {
            return "--:--"
        }

        let total = Int(seconds)

        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60

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
