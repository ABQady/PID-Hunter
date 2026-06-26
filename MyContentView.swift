import SwiftUI

struct MyContentView: View {
    struct ExportedFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    @State private var exportedFile: ExportedFile?
    
    @ObservedObject private var bt = BluetoothManager.shared
    @ObservedObject private var brute = BruteForceScanner.shared
    @ObservedObject private var logger = Logger.shared
    @State private var scrollPosition: Int?
    @State private var shouldAutoScroll = true
    @State private var selectedMode = 01
    @State private var header = "81F111"
    @State private var startPID = "0000"
    @State private var endPID = "FFFF"
    
    var body: some View {
        NavigationStack {
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
                    }
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 18
                        )
                    )
                    // MARK: Progress
                    VStack(alignment: .leading) {
                        Text("Progress")
                            .font(.headline)
                        ProgressView(
                            value: brute.progress
                        )
                        Text(
                            brute.currentRequest
                        )
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
                    // MARK: Actions
                    HStack(alignment:.center, spacing: 10) {
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
                            
                            switch selectedMode {
                            case 1:
                                brute.scanMode01()
                            case 21:
                                brute.scanMode21()
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
                                        brute.scanMode22(start: start, end: end)
                                    } else {
                                        Logger.shared.info("Start PID must be <= End PID")
                                    }
                                    
                                } else {
                                    Logger.shared.info("Invalid PID range")
                                    
                                }
                            }
                        } label: {
                            Label(
                                "Start Scan",
                                systemImage:
                                    "play.fill"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(brute.isScanning)
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
                        .disabled(!brute.isScanning)
                    }
                    

                    // MARK: Live Log
                    VStack(alignment: .leading) {
                        ScrollViewReader { proxy in
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Terminal")
                                        .font(.headline)
                                    Spacer()
                                    
                                    Text(bt.status.title)
                                        .font(.headline)
                                    Spacer()
                                    
                                    Button("▼ Live") {
                                        shouldAutoScroll = true
                                        
                                        if let last = logger.lines.indices.last {
                                            withAnimation {
                                                proxy.scrollTo(last, anchor: .bottom)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                ScrollView {
                                    LazyVStack(alignment: .leading, spacing: 4) {
                                        ForEach(logger.lines.indices, id: \.self) { i in
                                            Text(logger.lines[i])
                                                .font(.system(size: 11, design: .monospaced))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .id(i)
                                        }
                                    }
                                }
                                .simultaneousGesture(
                                    DragGesture()
                                        .onChanged { value in
                                            if value.translation.height > 10 {
                                                // المستخدم سحب لتحت (راح لفوق في اللوج)
                                                shouldAutoScroll = false
                                            }
                                        }
                                )
                                .onScrollGeometryChange(for: Bool.self) { geometry in
                                    geometry.contentOffset.y >=
                                    geometry.contentSize.height
                                    - geometry.containerSize.height
                                    - 20
                                } action: { _, isAtBottom in
                                    shouldAutoScroll = isAtBottom
                                }
                                .frame(height: 320)
                                .onChange(of: logger.lines.count) { _, _ in
                                    guard shouldAutoScroll,
                                          let last = logger.lines.indices.last else {
                                        return
                                    }
                                    
                                    withAnimation(.linear(duration: 0.1)) {
                                        proxy.scrollTo(last, anchor: .bottom)
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
                            .padding()
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
                        .navigationTitle("PID Hunter")
                    }
                }
            }
            .sheet(item: $exportedFile) { item in
                ShareSheet(activityItems: [item.url])
            }
        }
    }
}

#Preview {
        MyContentView()
}

