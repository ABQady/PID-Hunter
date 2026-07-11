//
//  BikeOverview.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 11/07/2026.
//

import SwiftUI

struct BikeOverviewCard: View {

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
            if let profile, let analytics {

                VStack(alignment: .leading, spacing: 20) {

                    HStack(alignment: .top) {

                        Image(systemName: "motorcycle")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(.thinMaterial)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {

                            Text(profile.displayName)
                                .font(.title2.weight(.bold))

                            Text(profile.fingerprint.header)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 6) {

                                Circle()
                                    .fill(.green)
                                    .frame(width: 8, height: 8)

                                Text("Connected")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()
                    }

                    Divider()

                    if !profile.headerDiscoveries.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Communication Profile")
                                .font(.headline)

                            ForEach(profile.headerDiscoveries, id: \.header) { discovery in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: "point.3.connected.trianglepath.dotted")
                                            .foregroundStyle(.blue)

                                        Text(discovery.header)
                                            .font(.headline.monospaced())
                                    }

                                    Text(discovery.supportedModes
                                        .map { $0.title }
                                        .joined(separator: " • "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.thinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        Divider()
                    }

                    HStack {

                        stat(
                            title: "Known",
                            value: "\(analytics.totalRequests)"
                        )

                        Spacer()

                        stat(
                            title: "Coverage",
                            value: analytics.coverageString
                        )

                        Spacer()

                        stat(
                            title: "Version",
                            value: "v\(profile.schemaVersion)"
                        )
                    }
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(
                    RoundedRectangle(cornerRadius: 20)
                )

            } else {

                ContentUnavailableView(
                    "No Bike Connected",
                    systemImage: "motorcycle",
                    description: Text(
                        "Connect to an ECU to build a Bike Profile."
                    )
                )
            }
        }
    }

    @ViewBuilder
    private func stat(
        title: String,
        value: String
    ) -> some View {

        VStack(alignment: .leading, spacing: 4) {

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
                .monospacedDigit()
        }
    }
}

#Preview {

    BikeOverviewCard()
        .padding()
        .environment(BikeProfileManager.shared)
}
