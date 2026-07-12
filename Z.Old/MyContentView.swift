//import SwiftUI
//struct MyContentView: View {
//    struct ExportedFile: Identifiable {
//        let id = UUID()
//        let url: URL
//    }
//
//    @State private var exportedFile: ExportedFile?
//    
//    @ObservedObject private var bt = BluetoothManager.shared
//    @ObservedObject private var brute = BruteForceScanner.shared
//    @ObservedObject private var logger = Logger.shared
//    @State private var scrollPosition: Int?
//    @State private var shouldAutoScroll = true
//    @State private var selectedMode = 1
//    @State private var header = "81F111"
//    @State private var startPID = "0000"
//    @State private var endPID = "FFFF"
//    
//    var body: some View {
//        NavigationStack {
//            ScrollView {
//                VStack(spacing: 18) {
//                    // MARK: Status
//                    HStack {
//                        Circle()
//                            .fill(
//                                bt.isConnected
//                                ? Color.green
//                                : Color.red
//                            )
//                            .frame(width: 12, height: 12)
//                        Text(
//                            bt.isConnected
//                            ? "Connected"
//                            : "Disconnected"
//                        )
//                        Spacer()
//                        Button("Scan BLE") {
//                            bt.startScan()
//                        }
//                        .disabled(bt.isScanning)
//                    }
//                    .padding()
//                    .background(.thinMaterial)
//                    .clipShape(
//                        RoundedRectangle(
//                            cornerRadius: 18
//                        )
//                    )
//                    // MARK: Configuration
//                    VStack(alignment: .leading, spacing: 12) {
//                        
//                        Text("Configuration")
//                            .font(.headline)
//                        HStack(alignment: .center){
//                            Text("Header")
//                                .font(.title3)
//                                .foregroundStyle(.secondary)
//                            
//                            Spacer()
//                            
//                            Picker("Header", selection: $header) {
//                                Text("81F111 - ECU ").tag("81F111")
//                                Text("80F111 - Common KWP").tag("80F111")
//                                Text("82F111 - Extended").tag("82F111")
//                            }
//                            .pickerStyle(.menu)
//                        }
//                        Text("OBD Mode")
//                            .font(.title3)
//                            .foregroundStyle(.secondary)
//                        
//                        Picker("Mode", selection: $selectedMode) {
//                            Text("01").tag(1)
//                            Text("21").tag(21)
//                            Text("22").tag(22)
//                        }
//                        .pickerStyle(.segmented)
//                        
//                        Text("PID Range")
//                            .font(.title3)
//                            .foregroundStyle(.secondary)
//                        
//                        HStack {
//                            VStack(alignment: .leading) {
//                                Text("Start PID")
//                                    .font(.caption)
//                                    .foregroundStyle(.secondary)
//                                
//                                TextField("0000", text: $startPID)
//                                    .textInputAutocapitalization(.characters)
//                                    .autocorrectionDisabled()
//                            }
//                            
//                            VStack(alignment: .leading) {
//                                Text("End PID")
//                                    .font(.caption)
//                                    .foregroundStyle(.secondary)
//                                
//                                TextField("FFFF", text: $endPID)
//                                    .textInputAutocapitalization(.characters)
//                                    .autocorrectionDisabled()
//                            }
//                        }
//                        Text("Request Delay: \(Int(brute.delayMs)) ms")
//                            .font(.title3)
//                            .foregroundStyle(.secondary)
//
//                        Slider(
//                            value: $brute.delayMs,
//                            in: 50...1000,
//                            step: 10
//                        )
//                    }
//                    .textFieldStyle(.roundedBorder)
//                    .padding()
//                    .background(.thinMaterial)
//                    .clipShape(
//                        RoundedRectangle(
//                            cornerRadius: 18
//                        )
//                    )
//                    // MARK: Progress
//                    VStack(alignment: .leading) {
//                        Text("Progress")
//                            .font(.headline)
//                        ProgressView(
//                            value: brute.scanStatus.progress
//                        )
//                        Text(
//                            "\(Int(brute.scanStatus.progress * 100))% • \(brute.scanStatus.currentRequest)"                        )
//                        .font(
//                            .system(
//                                .caption,
//                                design: .monospaced
//                            )
//                        )
//                    }
//                    .padding()
//                    .background(.thinMaterial)
//                    .clipShape(
//                        RoundedRectangle(
//                            cornerRadius: 18
//                        )
//                    )
//                    // MARK: Actions
//                    HStack(alignment:.center, spacing: 10) {
//                        Button {
//                            guard bt.isConnected else {
//                                
//                                Logger.shared.info("Connect to ELM first")
//                                
//                                return
//                                
//                            }
//                            Logger.shared.clear()
//                            RequestResponseMatcher.shared.clear()
//                            
//                            let cleanHeader = header
//                                .trimmingCharacters(in: .whitespacesAndNewlines)
//                                .uppercased()
//                            
//                            guard cleanHeader.count == 6,
//                                  cleanHeader.allSatisfy({ $0.isHexDigit }) else {
//                                Logger.shared.info("Invalid Header")
//                                return
//                            }
//                            brute.headers = [cleanHeader]
//                            
//                            switch selectedMode {
//                            case 1:
//                                Task {
//
//                                    let ok = await Preflight.shared.run(
//                                        header: cleanHeader
//                                    )
//                                    
//                                    guard ok else {
//                                        Logger.shared.info("❌ Preflight Failed")
//                                        return
//                                    }
//
//                                    brute.scanMode01()
//                                }
//                            case 21:
//                                Task {
//
//                                    let ok = await Preflight.shared.run(
//                                        header: cleanHeader
//                                    )
//                                    
//
//                                    guard ok else {
//                                        Logger.shared.info("❌ Preflight Failed")
//                                        return
//                                    }
//
//                                    brute.scanMode21()
//                                }
//                            default:
//                                let startText = startPID
//                                    .trimmingCharacters(in: .whitespacesAndNewlines)
//                                    .uppercased()
//                                
//                                let endText = endPID
//                                    .trimmingCharacters(in: .whitespacesAndNewlines)
//                                    .uppercased()
//                                
//                                if let start = UInt16(startText, radix: 16),
//                                   let end = UInt16(endText, radix: 16) {
//                                    
//                                    if start <= end {
//                                        Task {
//
//                                            let ok = await Preflight.shared.run(
//                                                header: cleanHeader
//                                            )
//
//                                            guard ok else {
//                                                Logger.shared.info("❌ Preflight Failed")
//                                                return
//                                            }
//
//                                            brute.scanMode22(
//                                                start: start,
//                                                end: end
//                                            )
//                                        }
//                                    } else {
//                                        Logger.shared.info("Start PID must be <= End PID")
//                                    }
//                                    
//                                } else {
//                                    Logger.shared.info("Invalid PID range")
//                                    
//                                }
//                            }
//                        } label: {
//                            Label(
//                                "Start Scan",
//                                systemImage:
//                                    "play.fill"
//                            )
//                        }
//                        .buttonStyle(.borderedProminent)
//                        .disabled(brute.scanStatus.isScanning)
//                        Button {
//                            Task {
//                                let cleanHeader = header
//                                    .trimmingCharacters(in: .whitespacesAndNewlines)
//                                    .uppercased()
//
//                                await ECUTester.shared.run(header: cleanHeader)
//                            }
//                        } label: {
//                            Label("Test ECU", systemImage: "stethoscope")
//                        }
//                        .buttonStyle(.bordered)
//                        
//                        Button(
//                            role: .destructive
//                        ) {
//                            brute.stop()
//                        } label: {
//                            Label(
//                                "Stop",
//                                systemImage:
//                                    "stop.fill"
//                            )
//                        }
//                        .disabled(!brute.scanStatus.isScanning)
//                    }
//                    
//
//                    // MARK: Live Log
//                    VStack(alignment: .leading) {
//                        ScrollViewReader { proxy in
//                            VStack(spacing: 8) {
//                                HStack {
//                                    Text("Terminal")
//                                        .font(.headline)
//                                    Spacer()
//                                    
//                                    Text(bt.status.title)
//                                        .font(.headline)
//                                    
//                                    Spacer()
//                                    
//                                    Text("Found: \(brute.scanStatus.successCount)")
//                                        .font(.headline)
//                                    
//                                    Spacer()
//                                    
//                                    Text("TX \(bt.txCount) • RX \(bt.rxCount)")
//                                            .font(.caption)
//                                            .foregroundStyle(.secondary)
//
//                                    Spacer()
//                                    
//                                    Button("▼ Live") {
//                                        shouldAutoScroll = true
//
//                                        if let last = logger.lines.indices.last {
//                                            proxy.scrollTo(last, anchor: .bottom)
//                                        }
//                                    }
//                                }
//                                .padding(.horizontal)
//                                ScrollView {
//                                    VStack(alignment: .leading, spacing: 4) {
//                                        ForEach(Array(logger.lines.enumerated()), id: \.element.id) { index, line in
//                                            Text(line.text)
//                                                .font(.system(size: 11, design: .monospaced))
//                                                .foregroundStyle(line.color)
//                                                .frame(maxWidth: .infinity, alignment: .leading)
//                                                .id(index)
//                                        }
//                                    }
//                                }
//                                .highPriorityGesture(
//                                    DragGesture(minimumDistance: 0)
//                                        .onChanged { _ in
//                                            shouldAutoScroll = false
//                                        }
//                                )
//                                .onScrollPhaseChange { _, newPhase in
//                                    if newPhase.isScrolling {
//                                        shouldAutoScroll = false
//                                    }
//                                }
//                                .frame(height: 320)
//                                .onChange(of: shouldAutoScroll) { _, newValue in
//                                    print("AutoScroll =", newValue)
//                                }
//                                .onChange(of: logger.lines.count) { _, _ in
//                                    guard shouldAutoScroll,
//                                          let last = logger.lines.indices.last else {
//                                        return
//                                    }
//                                        proxy.scrollTo(last, anchor: .bottom)
//                                }
//                                .padding()
//                                .background(.black.opacity(0.15))
//                                .clipShape(
//                                    RoundedRectangle(
//                                        cornerRadius: 18
//                                    )
//                                )
//                            }
//                            .padding()
//                            // MARK: Export
//                            HStack(alignment: .center) {
//                                Button("Export CSV") {
//                                    do {
//                                        let url = try CSVExporter.export(brute.results)
//                                        exportedFile = ExportedFile(url: url)
//                                    } catch {
//                                        print(error)
//                                    }
//                                }
//                                Button("Export Log") {
//                                    do {
//                                        let url = try Logger.shared.saveLog()
//                                        exportedFile = ExportedFile(url: url)
//                                    } catch {
//                                        print(error)
//                                    }
//                                }
//                            }
//                            .buttonStyle(
//                                .bordered
//                            )
//                            .padding()
//                            .background(.thinMaterial)
//                            .clipShape(
//                                RoundedRectangle(
//                                    cornerRadius: 18
//                                )
//                            )
//                        }
//                        .navigationTitle("PID Hunter")
//                    }
//                }
//            }
//            .sheet(item: $exportedFile) { item in
//                ShareSheet(activityItems: [item.url])
//            }
//        }
//    }
//}
//
//#Preview {
//        MyContentView()
//}
//
