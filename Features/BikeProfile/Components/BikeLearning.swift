//
//  BikeLearning.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 11/07/2026.
//

import SwiftUI

struct BikeLearningCard: View {

    @Environment(BikeProfileManager.self)
    private var manager

    @State
    private var selectedClassification: DiscoveryClassification?


    @State
    private var isShowingPartialResponsesSheet = false

    private var profile: BikeProfile? {
        manager.displayedProfile
    }

    private var analytics: BikeAnalytics? {
        profile.map(BikeAnalytics.init)
    }

    var body: some View {

        Group {
            if let analytics {

                VStack(alignment: .leading, spacing: 18) {

                    Label("Bike Learning", systemImage: "brain.head.profile")
                        .font(.headline)

                    if let profile,
                       !profile.headerDiscoveries.isEmpty {

                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(profile.headerDiscoveries, id: \.header) { discovery in
                                    DisclosureGroup {
                                        LazyVGrid(
                                            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                                            alignment: .leading,
                                            spacing: 12
                                        ) {
                                            ForEach(OBDMode.allCases, id: \.rawValue) { mode in
                                                let isSupported = discovery.supportedModes.contains(mode)
                                                ModeBadgeView(mode: mode, isSupported: isSupported)
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Label(discovery.header, systemImage: "externaldrive.connected.to.line.below")
                                                .font(.headline.monospaced())
                                            Spacer()
                                            Text("\(discovery.supportedModes.count)/\(OBDMode.allCases.count)")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                    .padding(.vertical, 2)
                                    if discovery.header != profile.headerDiscoveries.last?.header {
                                        Divider()
                                    }
                                }
                            }
                            // Removed top padding for a more compact section
                        } label: {
                            Label("Discovered Headers", systemImage: "point.3.connected.trianglepath.dotted")
                                .font(.subheadline.weight(.semibold))
                        }
                        Divider()
                    }

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ],
                        spacing: 14
                    ) {

                        statistic(
                            title: "Tried Requests",
                            value: "\(analytics.totalRequests)",
                            icon: "externaldrive.badge.checkmark",
                            tint: .blue
                        )

                        statistic(
                            title: "Coverage",
                            value: analytics.coverageString,
                            icon: "chart.pie.fill",
                            tint: .purple
                        )
                    }

                    Divider()

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ],
                        spacing: 14
                    ) {

                        Button {
                            selectedClassification = .positive
                        } label: {
                            statistic(
                                title: "Valid PIDs",
                                value: "\(analytics.positiveRequests)",
                                icon: "checkmark.circle.fill",
                                tint: .green
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            selectedClassification = .negative
                        } label: {
                            statistic(
                                title: "Negative",
                                value: "\(analytics.negativeRequests)",
                                icon: "xmark.circle.fill",
                                tint: .red
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            selectedClassification = .noData
                        } label: {
                            statistic(
                                title: "No Data",
                                value: "\(analytics.noDataRequests)",
                                icon: "minus.circle.fill",
                                tint: .orange
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            selectedClassification = .unknown
                        } label: {
                            statistic(
                                title: "Unknown",
                                value: "\(analytics.unknownRequests)",
                                icon: "questionmark.circle.fill",
                                tint: .gray
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            isShowingPartialResponsesSheet = true
                        } label: {
                            statistic(
                                title: "Partial Frames",
                                value: "\(analytics.partialResponseRequests)",
                                icon: "exclamationmark.triangle.fill",
                                tint: .yellow
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Divider()

                    statistic(
                        title: "Average Latency",
                        value: analytics.latencyString,
                        icon: "timer",
                        tint: .cyan
                    )
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 20,
                        style: .continuous
                    )
                )

            } else {

                ContentUnavailableView(
                    "No Learning Data",
                    systemImage: "brain.head.profile",
                    description: Text("Connect to an ECU once or select a saved bike profile.")
                )
            }
        }
        .sheet(item: $selectedClassification) { classification in
            if let profile {
                StoredKnowledgeSheet(
                    profile: profile,
                    classification: classification
                )
            }
        }
        .sheet(isPresented: $isShowingPartialResponsesSheet) {
            if let profile {
                StoredKnowledgeSheet(
                    profile: profile,
                    partialResponsesOnly: true
                )
            }
        }
        // Popover for mode info is now attached per badge button in the grid above.
    }

    @ViewBuilder
    private func statistic(
        title: String,
        value: String,
        icon: String? = nil,
        tint: Color = .accentColor
    ) -> some View {

        VStack(alignment: .leading, spacing: 8) {

            if let icon {

                Label(title, systemImage: icon)
                    .font(.caption)
                    .foregroundStyle(tint)

            } else {

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
        )
    }
}

#Preview {

    ScrollView {
        BikeLearningCard()
            .padding()
    }
    .environment(BikeProfileManager.shared)
}

//MARK: - ModeBadgeView

private struct ModeBadgeView: View {
    let mode: OBDMode
    let isSupported: Bool
    @State private var isShowingPopover = false

    var body: some View {
        Button {
            isShowingPopover = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isSupported ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption2)
                Text(mode.rawValue)
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
            }
            .foregroundStyle(isSupported ? .green : Color(red: 0.78, green: 0.36, blue: 0.40))
            .frame(minWidth: 44)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                (isSupported
                    ? Color.green.opacity(0.12)
                    : Color(red: 0.78, green: 0.36, blue: 0.40).opacity(0.10)
                )
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingPopover,
                 attachmentAnchor: .rect(.bounds),
                 arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Mode \(mode.rawValue)")
                    .font(.headline)

                Text("\(mode.rawValue) • \(mode.title)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(width: 220, alignment: .leading)
            .presentationCompactAdaptation(.popover)
        }
    }
}
