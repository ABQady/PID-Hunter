//
//  TabView.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 26/06/2026.
//

import SwiftUI
struct PIDHunterTabView: View {
    struct ExportedFile: Identifiable {
        let id = UUID()
        let url: URL
    }
    
    @ObservedObject private var bt = BluetoothManager.shared
    @ObservedObject private var brute = BruteForceScanner.shared
    @ObservedObject private var logger = Logger.shared
    
    @State private var exportedFile: ExportedFile?
    @State private var programmaticScroll = false
    @State private var search = ""
    @State private var shouldAutoScroll = true
    @State private var selectedMode = 1
    @State private var header = "81F111"
    @State private var startPID = "0000"
    @State private var endPID = "FFFF"
    @State private var manualCommand = ""
    
    @AppStorage("selectedTab")
    private var selectedTab = 0
    
    private var filteredResults: [ScanResult] {
        brute.results.filter {
            search.isEmpty ||
            $0.request.localizedCaseInsensitiveContains(search) ||
            $0.response.localizedCaseInsensitiveContains(search) ||
            $0.header.localizedCaseInsensitiveContains(search) ||
            $0.pid.localizedCaseInsensitiveContains(search)
        }
    }
    
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
    
    private var settingsTab: some View {
        ScrollView {
            
            VStack(spacing: 18) {
                
                // MARK: Status
                HStack {
                    Circle()
                        .fill(
                            bt.isConnected
                            ? Color.green
                            : Color.red
                        )
                        .frame(width: 12, height: 12)
                    Text(
                        bt.isConnected
                        ? "Connected"
                        : "Disconnected"
                    )
                    Spacer()
                    Button("Scan BLE") {
                        bt.startScan()
                    }
                    .disabled(bt.isScanning)
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 18
                    )
                )
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
                    Text("Request Delay: \(Int(brute.delayMs)) ms")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    
                    Slider(
                        value: $brute.delayMs,
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
                
                // MARK: Export
                HStack(alignment: .center) {
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
                }
                .buttonStyle(
                    .bordered
                )
                .padding()
                .background(.thinMaterial)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 18
                    )
                )
            }
            .padding()
        }
    }
    
    
    private var terminalTab: some View {
        
        VStack(spacing: 18) {
            // MARK: Progress
            VStack(alignment: .leading) {
                Text("Progress")
                    .font(.headline)
                ProgressView(
                    value: brute.scanStatus.progress
                )
                Text(
                    "\(Int(brute.scanStatus.progress * 100))% • \(brute.scanStatus.currentRequest)"                        )
                .font(
                    .system(
                        .caption,
                        design: .monospaced
                    )
                )
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 18
                )
            )
            if brute.hasResumePoint {

                Text("Resume available")

                    .font(.caption)

                    .foregroundStyle(.orange)

            }
            
            // MARK: Actions
            HStack(alignment:.center, spacing: 10) {
                Button(role: .destructive) {
                    brute.startFresh()
                    Logger.shared.info("🗑️ Starting fresh scan")
                } label: {
                    Label("New Scan", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button {
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
                    selectedTab = 1
                    
                    switch selectedMode {
                    case 1:
                        Task {
                            
                            let ok = await Preflight.shared.run(
                                header: cleanHeader
                            )
                            
                            guard ok else {
                                Logger.shared.info("❌ Preflight Failed")
                                return
                            }
                            
                            brute.scanMode01()
                        }
                    case 21:
                        Task {
                            
                            let ok = await Preflight.shared.run(
                                header: cleanHeader
                            )
                            
                            
                            guard ok else {
                                Logger.shared.info("❌ Preflight Failed")
                                return
                            }
                            
                            brute.scanMode21()
                        }
                    default:
                        let startText = startPID
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .uppercased()
                        
                        let endText = endPID
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .uppercased()
                        
                        if let start = UInt16(startText, radix: 16),
                           let end = UInt16(endText, radix: 16) {
                            
                            if start <= end {
                                Task {
                                    
                                    let ok = await Preflight.shared.run(
                                        header: cleanHeader
                                    )
                                    
                                    guard ok else {
                                        Logger.shared.info("❌ Preflight Failed")
                                        return
                                    }
                                    
                                    brute.scanMode22(
                                        start: start,
                                        end: end
                                    )
                                }
                            } else {
                                Logger.shared.info("Start PID must be <= End PID")
                            }
                            
                        } else {
                            Logger.shared.info("Invalid PID range")
                            
                        }
                    }
                } label: {
                    Label(
                        "Resume Scan",
                        systemImage:
                            "play.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(brute.scanStatus.isScanning)
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
                
                Button(
                    role: .destructive
                ) {
                    brute.stop()
                } label: {
                    Label(
                        "Stop",
                        systemImage:
                            "stop.fill"
                    )
                }
                .disabled(!brute.scanStatus.isScanning)
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
                            .font(.caption)
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
                            ForEach(logger.lines.indices, id: \.self) { i in
                                Text(logger.lines[i])
                                    .font(.system(size: 11, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(i)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            .background(.black.opacity(0.15))
            
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .padding()
    }
    
    
    
    private var resultsTab: some View {
        VStack(spacing: 16) {

            HStack {
                Text("Found Results")
                    .font(.largeTitle.bold())

                Spacer()

                Text("\(filteredResults.count) / \(brute.results.count)")
                    .foregroundStyle(.secondary)
            }
            Button("Copy All") {

                let text = brute.results.map {
                    "\($0.request) -> \($0.response)"
                }
                .joined(separator: "\n")

            #if os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            #endif
            }
            .buttonStyle(.borderedProminent)
            
            List(filteredResults.reversed()) { result in

                VStack(alignment: .leading, spacing: 6) {

                    HStack {
                        Text(result.request)
                            .font(.system(.headline, design: .monospaced))
                        Spacer()

                        Text(result.header)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    Text(result.response)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(nil)

                    HStack {

                        Text("Mode: \(result.mode)")

                        Spacer()

                        Text("PID: \(result.pid)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .searchable(text: $search)
                .padding(.vertical, 4)
            }
        }
        .padding()
    }
    
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                settingsTab.tag(0)
                    .tabItem {
                        
                        Label("Settings", systemImage: "dot.radiowaves.left.and.right")
                    }
                
                terminalTab.tag(1)
                    .tabItem {
                        Label("Terminal", systemImage: "terminal")
                    }
                
                resultsTab.tag(2)
                    .tabItem {
                        Label("Results", systemImage: "chart.bar")
                    }
            }
            .navigationTitle("PID Hunter")
        }
        .sheet(item: $exportedFile) { item in
            ShareSheet(activityItems: [item.url])
        }
    }
}
