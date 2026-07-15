import SwiftUI

#if os(macOS)
    import AppKit
#endif

struct ResultsView: View {
    @ObservedObject private var bt = BluetoothManager.shared
    @ObservedObject private var brute = BruteForceScanner.shared
    @ObservedObject private var ecu = ECUInfo.shared
    @ObservedObject private var stats = ScanStatistics.shared
    
    @State private var search = ""
    @State private var ecuExpanded = true
    @State private var statsExpanded = true
    @State private var searchStatsExpanded = false

    @State private var isFollowingLiveResults = true

    private var filteredResults: [ScanResult] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = brute.results
        guard !query.isEmpty else {
            return source
        }
        return source.filter {
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
        ScrollViewReader { scrollProxy in
        ScrollView {
            LazyVStack(
                alignment: .leading,
                spacing: 12,
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
                }
                .font(.headline)
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18))

                // MARK: - Statistics Section
                // MARK: - Scan Statistics
                
                // Scan Statistics describe the current scan session
                // (requests, responses, timing and transport health).
                DisclosureGroup("Scan Statistics", isExpanded: $statsExpanded) {
                    Divider()
                    HStack {
                        statistic(title: "Requests", value: "\(stats.requestsSent)")
                        Spacer()
                        statistic(title: "Responses", value: "\(stats.responses)")
                        Spacer()
                        statistic(title: "Partial", value: "\(stats.partialFrames)")
                    }.padding(.bottom)
                    HStack {
                        statistic(title: "NO DATA", value: "\(stats.noData)")
                        Spacer()
                        statistic(title: "Bus Errors", value: "\(stats.busErrors)")
                        Spacer()
                        statistic(title: "Timeouts", value: "\(stats.timeouts)")
                    }.padding(.bottom)
                    HStack {
                        statistic(title: "Elapsed", value: formattedElapsed())
                        Spacer()
                        statistic(title: "ETA", value: formattedETA())
                        Spacer()
                    }
                }
                .font(.headline)
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18))

                if showsSearchStatistics {
                    // Search Statistics are algorithm metrics.
                    // Scan Statistics are transport/session metrics.
                    // Do not duplicate values between them.
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
                                title: "Discoveries",
                                value: "\(brute.statistics.successfulResponses)"
                            )
                            Spacer()
                            statistic(
                                title: "Misses",
                                value: "\(brute.statistics.failedResponses)"
                            )
                        }.padding(.bottom)
                        HStack {
                            Spacer()
                            statistic(
                                title: "Discovery Rate",
                                value: String(
                                    format: "%.1f%%",
                                    brute.statistics.successRate * 100
                                )
                            )
                            Spacer()
                        }.padding(.bottom)
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
                                title: "Avg",
                                value: String(
                                    format: "%.0f ms",
                                    brute.statistics.averageLatency * 1000
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
                        ForEach(filteredResults) { result in
                            PIDResultCard(result: result)
                                .id(result.id)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.preference(
                                            key: VisiblePIDPreferenceKey.self,
                                            value: [VisiblePIDPreferenceData(id: result.id, minY: geo.frame(in: .named("ResultsScroll")).minY)]
                                        )
                                    }
                                )
                                .padding(.vertical, 6)
                        }
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
        .coordinateSpace(name: "ResultsScroll")
        .onPreferenceChange(VisiblePIDPreferenceKey.self) { values in
            let candidate = values
                .filter { $0.minY >= -1 }
                .min(by: { $0.minY < $1.minY })

            guard let firstID = filteredResults.first?.id else {
                isFollowingLiveResults = true
                return
            }

            isFollowingLiveResults = (candidate == nil) || (candidate?.id == firstID)
        }
        // Only live-follow if user is at the head; otherwise, preserve scroll position.
        .onChange(of: brute.results.count) {
            guard let firstID = filteredResults.first?.id else { return }

            guard isFollowingLiveResults else {
                return
            }

            var transaction = Transaction()
            transaction.animation = nil

            withTransaction(transaction) {
                scrollProxy.scrollTo(firstID, anchor: .top)
            }
        }
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

private struct VisiblePIDPreferenceData: Equatable {
    let id: ScanResult.ID
    let minY: CGFloat
}

private struct VisiblePIDPreferenceKey: PreferenceKey {
    static var defaultValue: [VisiblePIDPreferenceData] = []

    static func reduce(value: inout [VisiblePIDPreferenceData], nextValue: () -> [VisiblePIDPreferenceData]) {
        value = nextValue()
    }
}
