//
//  ProgressCard.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 04/07/2026.
//

import SwiftUI
import Combine

struct ProgressCard: View {

    @ObservedObject private var progressStatistics = ProgressStatistics.shared

    let successRate: Double
    let averageLatency: Double
    
    let isScanning: Bool
    let isCompleted: Bool
    let hasResumePoint: Bool

    let currentMode: OBDMode

    init(
        successRate: Double,
        averageLatency: Double,
        isScanning: Bool,
        isCompleted: Bool,
        hasResumePoint: Bool,
        currentMode: OBDMode
    ) {
        self.successRate = successRate
        self.averageLatency = averageLatency
        self.isScanning = isScanning
        self.isCompleted = isCompleted
        self.hasResumePoint = hasResumePoint
        self.currentMode = currentMode
    }

    private var progress: Double { progressStatistics.progress }
    private var currentRequests: Int { progressStatistics.completed }
    private var totalRequests: Int { progressStatistics.total }

    @inline(__always)
    private func formatETA(_ seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "--:--" }
        let totalSeconds = max(0, Int(seconds.rounded(.down)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
    
    var body: some View {

        VStack(alignment: .leading) {
            HStack {
                Text("Progress")
                    .font(.headline)

                Spacer()

                Text("Mode: \(currentMode.rawValue)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(maxWidth: .infinity)
                ViewThatFits(in: .horizontal) {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        let elapsed = formatETA(progressStatistics.elapsed)
                        let eta = formatETA(progressStatistics.estimatedRemaining)
                        HStack(spacing: 4) {
                            Text("Elapsed: \(elapsed)")
                            if isCompleted {
                                Text("Completed in \(elapsed) ✅")
                            } else if !isScanning {
                                Text("ETA: --:--")
                            } else {
                                Text("ETA: \(eta)")
                            }
                        }
                    }
                    .font(.system(.caption, design: .monospaced))
                    
                    VStack(alignment: .leading, spacing: 2) {

                        Text("\(Int(progress * 100))% • \(currentRequests)/\(totalRequests)")

                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            let elapsed = formatETA(progressStatistics.elapsed)
                            let eta = formatETA(progressStatistics.estimatedRemaining)
                            VStack(alignment: .leading, spacing: 2) {

                                Text("Elapsed: \(elapsed)")

                                if isCompleted {
                                    Text("Completed in \(elapsed) ✅")
                                } else if !isScanning {
                                    Text("ETA: --:--")
                                } else {
                                    Text("ETA: \(eta)")
                                }
                            }
                        }
                    }
                    .font(.system(.caption, design: .monospaced))
                }
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
