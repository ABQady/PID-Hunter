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
    @State private var searchStatsExpanded = false

    private var filteredResults: [ScanResult] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return brute.results }

        return brute.results.filter {
            $0.request.localizedCaseInsensitiveContains(query)
                || $0.response.localizedCaseInsensitiveContains(query)
                || $0.header.localizedCaseInsensitiveContains(query)
                || $0.pid.localizedCaseInsensitiveContains(query)
        }
    }
    

    private var hasResults: Bool {
        !filteredResults.isEmpty
    }

    @AppStorage("selectedSearchEngine")
    private var selectedSearchEngine = SearchEngineType.sequential.rawValue

    private var showsSearchStatistics: Bool {
        SearchEngineType(rawValue: selectedSearchEngine) != .sequential
    }
    

    // MARK: - Results View
    private var resultsView: some View {
        
        ScrollView {
            LazyVStack(
                alignment: .leading,
                spacing: 16,
                pinnedViews: [.sectionHeaders]
            ) {
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
                            Text(
                                date.formatted(
                                    date: .omitted,
                                    time: .standard
                                )
                            )
                        }
                    }

                    Divider()

//                    LabeledContent("Supported Services") {
//                        if ecu.services.services.isEmpty {
//                            Text("-")
//                                .foregroundStyle(.secondary)
//                        } else {
//                            LazyVGrid(
//                                columns: [
//                                    GridItem(.adaptive(minimum: 80))
//                                ],
//                                alignment: .leading,
//                                spacing: 8
//                            ) {
//                                ForEach(ecu.services.services, id: \.self) {
//                                    service in
//                                    Text(service)
//                                        .font(
//                                            .system(
//                                                .caption,
//                                                design: .monospaced
//                                            ).bold()
//                                        )
//                                        .foregroundStyle(.green)
//                                        .padding(.horizontal, 10)
//                                        .padding(.vertical, 5)
//                                        .background(.green.opacity(0.15))
//                                        .overlay {
//                                            Capsule()
//                                                .stroke(.green.opacity(0.35))
//                                        }
//                                        .clipShape(Capsule())
//                                }
//                            }
//                            .frame(maxWidth: .infinity, alignment: .leading)
//                        }
//                    }
                    if !discovery.supportedModes.isEmpty {

                        Divider()
                            .padding(.vertical, 8)

                        Text("Supported Modes")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 80))
                            ],
                            alignment: .leading,
                            spacing: 8
                        ) {
                            ForEach(
                                discovery.supportedModes
                                    .sorted(by: { $0.requestService < $1.requestService })
                            ) { mode in
                                Text("\(mode.rawValue) • \(mode.title)")
                                    .font(
                                        .system(
                                            .caption,
                                            design: .monospaced
                                        ).bold()
                                    )
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
                .font(.headline)
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18))

                // MARK: - Statistics Section
                // MARK: - Scan Statistics
                Divider()
                
                // Scan Statistics describe the current scan session
                // (requests, responses, timing and transport health).
                DisclosureGroup("Scan Statistics", isExpanded: $statsExpanded) {
                    Divider()
                    HStack {
                        statistic(
                            title: "Requests",
                            value: "\(stats.requestsSent)"
                        )
                        Spacer()
                        statistic(
                            title: "Hits",
                            //value: "\(brute.scanStatus.successCount)"
                            value: "\(stats.positiveResponses)"
                        )

                        Spacer()

                        statistic(
                            title: "Hit Rate",
                            value: String(
                                format: "%.1f%%",
                                stats.positiveResponseRate
                            )
                        )
                    }

                    HStack {
                        statistic(title: "NO DATA", value: "\(stats.noData)")

                        Spacer()

                        statistic(
                            title: "Bus Errors",
                            value: "\(stats.busErrors)"
                        )

                        Spacer()

                        statistic(
                            title: "Timeouts",
                            value: "\(stats.timeouts)"
                        )
                    }

                    HStack {
                        statistic(
                            title: "Elapsed",
                            value: formattedElapsed()
                        )

                        Spacer()

                        statistic(
                            title: "ETA",
                            value: formattedETA()
                        )

                        Spacer()

                        statistic(
                            title: "Failures",
                            value: String(
                                format: "%.1f%%",
                                stats.failureRate
                            )
                        )
                    }

                }
                .font(.headline)
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18))

                if showsSearchStatistics {
                    // Search Statistics describe the search engine's performance
                    // (discoveries, success rate and latency).
                    DisclosureGroup(
                        "Search Statistics",
                        isExpanded: $searchStatsExpanded
                    ) {
                        Divider()
                        HStack {
                            statistic(
                                title: "Requests",
                                value: "\(brute.statistics.requestsSent)"
                            )

                            Spacer()

                            statistic(
                                title: "Successes",
                                value: "\(brute.statistics.successfulResponses)"
                            )

                            Spacer()

                            statistic(
                                title: "Failures",
                                value: "\(brute.statistics.failedResponses)"
                            )
                        }
                        HStack {
                            statistic(
                                title: "Success Rate",
                                value: String(
                                    format: "%.1f%%",
                                    brute.statistics.successRate * 100
                                )
                            )

                            Spacer()

                            statistic(
                                title: "Avg",
                                value: String(
                                    format: "%.0f ms",
                                    brute.statistics.averageLatency * 1000
                                )
                            )
                        }

                        HStack {
                            statistic(
                                title: "Fastest",
                                value: String(
                                    format: "%.0f ms",
                                    brute.statistics.fastestSuccessfulResponse
                                        * 1000
                                )
                            )

                            Spacer()

                            statistic(
                                title: "Slowest",
                                value: String(
                                    format: "%.0f ms",
                                    brute.statistics.slowestResponse * 1000
                                )
                            )

                            Spacer()

                            statistic(title: "", value: "")
                        }
                    }
                    .font(.headline)
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }

                // MARK: - PID Results
                Section {
                    if !hasResults {

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
                        .clipShape(RoundedRectangle(cornerRadius: 18))

                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(filteredResults.reversed())) {
                                result in
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

                            Label(
                                "\(brute.scanStatus.successCount)",
                                systemImage: "checkmark.circle.fill"
                            )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .help("Unique PID discoveries")

                            Spacer()

                            Button("Copy All") {
                                guard hasResults else { return }
                                let text =
                                    filteredResults
                                    .map { "\($0.request) -> \($0.response)" }
                                    .joined(separator: "\n")

                                #if os(macOS)
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(
                                        text,
                                        forType: .string
                                    )
                                #endif
                            }
                        }

                        TextField("Search PID...", text: $search)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }

            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Result Helpers
    @inline(__always)
    private func formattedElapsed() -> String {
        Duration.seconds(stats.elapsed(at: .now))
            .formatted(
                .units(
                    allowed: [.hours, .minutes, .seconds],
                    width: .abbreviated
                )
            )
    }

    @inline(__always)
    private func formattedETA() -> String {
        let eta = stats.eta(at: .now)
        guard eta > 0 else { return "--" }

        return Duration.seconds(eta)
            .formatted(
                .units(
                    allowed: [.hours, .minutes, .seconds],
                    width: .abbreviated
                )
            )
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
                .multilineTextAlignment(.center)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    var body: some View {
        
        resultsView
    }
}
