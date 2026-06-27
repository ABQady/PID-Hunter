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
    @ObservedObject private var ecu = ECUInfo.shared
    @ObservedObject private var stats = ScanStatistics.shared
    
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
                    ScanStatistics.shared.start()
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
                    ScanStatistics.shared.start()
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
                            ScanStatistics.shared.start()
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
                    guard bt.isConnected else {
                            Logger.shared.info("Connect to ELM first")
                            return
                        }
                    brute.startFresh()
                    Logger.shared.info("🗑️ Starting fresh scan")
                    startPIDScan()
                } label: {
                    Label("New Scan", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button {
                    startPIDScan()
                }
                label: {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            .background(.black.opacity(0.15))
            
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .padding()
    }
    
    
    
    private var resultsTab: some View {
        VStack(spacing: 16) {
            ///Mark ECU INFO
            VStack(alignment: .leading, spacing: 10) {
                
                Text("ECU Information")
                    .font(.headline)
                
                Divider()
                
                LabeledContent("Connection Status") {
                    Text(ecu.status)
                        .foregroundStyle(
                            ecu.status == "Connected"
                            ? .green
                            : .secondary
                        )
                }
                
                LabeledContent("ECU Name") {
                    Text(ecu.ecuName)
                }
                
                LabeledContent("ELM Version") {
                    Text(ecu.elmVersion)
                }
                
                LabeledContent("Protocol Used") {
                    Text(ecu.protocolName)
                }
                
                LabeledContent("Current Header") {
                    Text(ecu.header)
                }
                
                if let date = ecu.lastConnected {
                    LabeledContent("Connected") {
                        Text(date.formatted(
                            date: .omitted,
                            time: .standard
                        ))
                    }
                }
                
                Divider()
                
                LabeledContent("Supported Services") {
                    if ecu.services.services.isEmpty {
                        Text("-")
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 50))
                            ],
                            alignment: .leading,
                            spacing: 8
                        ) {
                            ForEach(ecu.services.services, id: \.self) { service in
                                Text(service)
                                    .font(.system(.caption, design: .monospaced).bold())
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.green.opacity(0.15))
                                    .overlay {
                                        Capsule()
                                            .stroke(.green.opacity(0.35))
                                    }
                                    .clipShape(Capsule())
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            
            
            ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                
                Text("Scan Statistics")
                    .font(.headline)
                
                Divider()
                
                HStack {
                    
                    statistic(
                        title: "Requests",
                        value: "\(stats.requestsSent)"
                    )
                    
                    Spacer()
                    
                    statistic(
                        title: "Responses",
                        value: "\(stats.responses)"
                    )
                    
                    Spacer()
                    
                    statistic(
                        title: "Hits",
                        value: "\(stats.positiveResponses)"
                    )
                }
                
                HStack {
                    
                    statistic(
                        title: "NO DATA",
                        value: "\(stats.noData)"
                    )
                    
                    Spacer()
                    
                    statistic(
                        title: "Bus Errors",
                        value: "\(stats.busErrors)"
                    )
                    
                    Spacer()
                    
                    statistic(
                        title: "Hit Rate",
                        value: String(format: "%.1f%%",
                                      stats.positiveResponseRate)
                    )
                }
                
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(
                RoundedRectangle(cornerRadius: 18)
            )
            
            Divider()
            
            HStack {
                Text("PID Results")
                    .font(.headline)

                Spacer()

                    Text("\(filteredResults.count)")
                        .foregroundStyle(.secondary)
                
                Spacer()
                
            Button("Copy All") {
                let text = brute.results
                    .map { "\($0.request) -> \($0.response)" }
                    .joined(separator: "\n")
                
#if os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
#endif
            }
        }
            .buttonStyle(.borderedProminent)
            
            TextField("Search PID...", text: $search)
                .textFieldStyle(.roundedBorder)

            if filteredResults.isEmpty {

                ContentUnavailableView {
                    Label(
                        "No PID Results",
                        systemImage: "memorychip"
                    )
                } description: {
                    if bt.isConnected {
                        Text("Start a scan to discover supported PIDs.")
                    } else {
                        Text("Connect an ELM327 adapter to begin.")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredResults.reversed()) { result in
                            PIDResultCard(result: result)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        
        }
        .padding()
    }
    
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    @ViewBuilder
    private func statistic(
        title: String,
        value: String
    ) -> some View {

        VStack {

            Text(value)
                .font(.title2.bold())
                .monospacedDigit()

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

        }
        .frame(maxWidth: .infinity)
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
