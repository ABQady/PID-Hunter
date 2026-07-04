//
//  ProgressCard.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 04/07/2026.
//

import SwiftUI

struct ProgressCard: View {

    let progress: Double

    let currentRequests: Int
    let totalRequests: Int

    let elapsed: String
    let eta: String

    let successRate: Double
    let averageLatency: Double
    
    let isScanning: Bool
    let isCompleted: Bool
    let hasResumePoint: Bool

    var body: some View {

        VStack(alignment: .leading) {
                Text("Progress")
                    .font(.headline)
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(maxWidth: .infinity)
                ViewThatFits(in: .horizontal) {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
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
            .overlay(
                Group {
                    if hasResumePoint && !isScanning {
                        VStack {
                            Spacer()
                            HStack {
                                Text("Resume available")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            )
        
    }
}
