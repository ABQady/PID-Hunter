//
//  BikeAnalyticsCard.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 11/07/2026.
//

import SwiftUI

struct BikeAnalyticsCard: View {

    let context: BikeProfileContext?

    private var analytics: BikeAnalytics? {
        context?.analytics
    }
    
    private var communicationBadgeTitle: String {
        switch analytics?.communicationScore ?? 0 {
        case 90...:
            return "Excellent"
        case 75..<90:
            return "Good"
        case 50..<75:
            return "Fair"
        default:
            return "Poor"
        }
    }

    private var communicationBadgeColor: Color {
        switch analytics?.communicationScore ?? 0 {
        case 90...:
            return .green
        case 75..<90:
            return .blue
        case 50..<75:
            return .orange
        default:
            return .red
        }
    }

    var body: some View {
        Group {
            if let analytics {
                VStack(alignment: .leading, spacing: 16) {

                    HStack {
                        Label("Bike Analytics", systemImage: "chart.xyaxis.line")
                            .font(.title3.bold())

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(analytics.communicationScoreString)
                                .font(.title.bold())
                                .monospacedDigit()

                            Text(communicationBadgeTitle)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(communicationBadgeColor.opacity(0.18))
                                .foregroundStyle(communicationBadgeColor)
                                .clipShape(Capsule())
                        }
                    }

                    ProgressView(value: analytics.communicationScore / 100)
                        .tint(communicationBadgeColor)
                    
                    Divider()

                    VStack(spacing: 8) {
                        row("Avg Latency", String(format: "%.0f ms", analytics.averageLatency * 1000))
                        row("Fastest", String(format: "%.0f ms", analytics.fastestResponse * 1000))
                        row("Slowest", String(format: "%.0f ms", analytics.slowestResponse * 1000))
                    }

                    Divider()

                    VStack(spacing: 8) {
                        row("Strongest Mode", analytics.strongestMode)
                        row("Weakest Mode", analytics.weakestMode)
                        row("Dominant", String(describing: analytics.dominantClassification).capitalized)
                        row("Coverage", analytics.coverageString)
                    }
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                ContentUnavailableView(
                    "No Analytics",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Connect to an ECU once or select a saved bike profile.")
                )
            }
        }
    }

    @ViewBuilder
    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.headline)
                .monospacedDigit()
        }
    }
}

#Preview {
    BikeAnalyticsCard(context: nil)
        .padding()
}
