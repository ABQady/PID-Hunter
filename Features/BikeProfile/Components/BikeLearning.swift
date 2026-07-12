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

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Discovered Headers")
                                .font(.subheadline.weight(.semibold))

                            ForEach(profile.headerDiscoveries, id: \.header) { discovery in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(discovery.header)
                                            .font(.headline.monospaced())

                                        Spacer()

                                        Text("\(discovery.supportedModes.count) modes")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Text(discovery.supportedModes
                                        .map { $0.title }
                                        .joined(separator: " • "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(.thinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
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
