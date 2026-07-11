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

    private var profile: BikeProfile? {
        manager.currentProfile
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

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ],
                        spacing: 14
                    ) {

                        statistic(
                            title: "Known Requests",
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

                        statistic(
                            title: "Positive",
                            value: "\(analytics.positiveRequests)",
                            icon: "checkmark.circle.fill",
                            tint: .green
                        )

                        statistic(
                            title: "Negative",
                            value: "\(analytics.negativeRequests)",
                            icon: "xmark.circle.fill",
                            tint: .red
                        )

                        statistic(
                            title: "No Data",
                            value: "\(analytics.noDataRequests)",
                            icon: "minus.circle.fill",
                            tint: .orange
                        )

                        statistic(
                            title: "Unknown",
                            value: "\(analytics.unknownRequests)",
                            icon: "questionmark.circle.fill",
                            tint: .gray
                        )
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
                    description: Text("Run a scan to start building your bike knowledge.")
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
