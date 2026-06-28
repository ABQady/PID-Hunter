import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ResultsView: View {
    @ObservedObject private var bt = BluetoothManager.shared
    @ObservedObject private var brute = BruteForceScanner.shared
    @ObservedObject private var ecu = ECUInfo.shared
    @ObservedObject private var stats = ScanStatistics.shared
    @ObservedObject private var discovery = ModeDiscovery.shared
    
    @State private var search = ""
    @State private var ecuExpanded = true
    @State private var statsExpanded = true
    
    private var filteredResults: [ScanResult] {
        brute.results.filter {
            search.isEmpty ||
            $0.request.localizedCaseInsensitiveContains(search) ||
            $0.response.localizedCaseInsensitiveContains(search) ||
            $0.header.localizedCaseInsensitiveContains(search) ||
            $0.pid.localizedCaseInsensitiveContains(search)
        }
    }
    
    // MARK: - Results View
    private var resultsView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
                // MARK: - ECU Information
                DisclosureGroup("ECU Information", isExpanded: $ecuExpanded) {
                    
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
                        
                        if !discovery.supportedModes.isEmpty {

                            Divider()
                                .padding(.vertical, 8)

                            Text("Discovered Modes")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            LazyVGrid(
                                columns: [
                                    GridItem(.adaptive(minimum: 50))
                                ],
                                alignment: .leading,
                                spacing: 8
                            ) {
                                ForEach(discovery.supportedModes) { mode in
                                    Text(mode.rawValue)
                                        .font(.system(.caption, design: .monospaced).bold())
                                        .foregroundStyle(.blue)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(.blue.opacity(0.15))
                                        .overlay {
                                            Capsule()
                                                .stroke(.blue.opacity(0.35))
                                        }
                                        .clipShape(Capsule())
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if !discovery.supportedModes.isEmpty {
                            
                            Divider()
                                .padding(.vertical, 8)

                            Text("Discovered Modes")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            LazyVGrid(
                                columns: [
                                    GridItem(.adaptive(minimum: 50))
                                ],
                                alignment: .leading,
                                spacing: 8
                            ) {
                                ForEach(discovery.supportedModes) { mode in
                                    Text(mode.rawValue)
                                        .font(.system(.caption, design: .monospaced).bold())
                                        .foregroundStyle(.blue)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(.blue.opacity(0.15))
                                        .overlay {
                                            Capsule()
                                                .stroke(.blue.opacity(0.35))
                                        }
                                        .clipShape(Capsule())
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .font(.headline)
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                
                
                // MARK: - Scan Statistics
                Divider()
                
                DisclosureGroup("Scan Statistics", isExpanded: $statsExpanded) {
                    
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
                            value: "\(stats.positiveResponses)/\(stats.totalRequests)"
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
                            title: "Avg",
                            value: String(format: "%.0f ms", stats.averageRequestTime * 1000)
                        )
                    }

                    HStack {
                        statistic(
                            title: "Elapsed",
                            value: Duration.seconds(stats.elapsed)
                                .formatted(.units(
                                    allowed: [.hours, .minutes, .seconds],
                                    width: .abbreviated
                                ))
                        )

                        Spacer()

                        statistic(
                            title: "ETA",
                            value: stats.eta > 0
                                ? Duration.seconds(stats.eta)
                                    .formatted(.units(
                                        allowed: [.hours, .minutes, .seconds],
                                        width: .abbreviated
                                    ))
                                : "--"
                        )

                        Spacer()

                        statistic(
                            title: "Hit Rate",
                            value: String(format: "%.1f%%", stats.positiveResponseRate)
                        )
                    }
                    
                }
                .font(.headline)
                .padding()
                .background(.thinMaterial)
                .clipShape(
                    RoundedRectangle(cornerRadius: 18)
                )
                
                // MARK: - PID Results
                Section {
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
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 250)
                        
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredResults.reversed()) { result in
                                PIDResultCard(result: result)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    VStack(spacing: 10) {
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
                        
                        TextField("Search PID...", text: $search)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding()
                    .background(.regularMaterial)
                }
                
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
        // MARK: - Helpers
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
        
        var body: some View {
            
            resultsView
        }
    }
