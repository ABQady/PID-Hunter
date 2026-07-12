//
//  TerminalHeader.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 04/07/2026.
//

import SwiftUI

struct TerminalHeader: View {

    let title: String
    let status: String

    let found: Int
    let successRate: Double
    let averageLatency: Double

    let txCount: Int
    let rxCount: Int

    let isCompact: Bool

    let onJumpToLive: () -> Void

    var body: some View {

            ViewThatFits(in: .horizontal) {
                HStack(spacing: isCompact ? 4 : 16) {
                    Text("Terminal")
                        .font(isCompact ? .body.weight(.semibold) : .headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.leading, isCompact ? -10 : 0)
                        .layoutPriority(2)
                    if !isCompact {
                        Spacer()
                    }
                    Text(isCompact ? status : status)
                        .font(isCompact ? .caption2 : .headline)
                        .lineLimit(1)
                        .allowsTightening(true)
                        .minimumScaleFactor(0.35)
                        .layoutPriority(10)
                    
                    if !isCompact {
                        Spacer()
                    }
                    
                    Text(isCompact ? "F: \(found)" : "Found: \(found)")
                        .font(isCompact ? .caption2.monospacedDigit() : .headline)
                        .fixedSize()
                    
                    Text(String(format: isCompact ? "%.0f%%" : "%.0f%%", successRate * 100))
                        .font(isCompact ? .caption2.monospacedDigit() : .headline)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                    
                    if !isCompact {
                        Spacer()
                    }
                    
                    Text(
                        isCompact
                        ? String(format: "%.0fms %d/%d", averageLatency * 1000, txCount, rxCount)
                        : String(format: "%.0f ms • TX %d • RX %d", averageLatency * 1000, txCount, rxCount)
                    )
                    .font(isCompact ? .caption2.monospacedDigit() : .headline)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    
                    if !isCompact {
                        Spacer()
                    }
                    
                    Button {
                        onJumpToLive()
                    } label: {
                        if isCompact {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.title2.weight(.semibold))
                        } else {
                            Text("▼ Live")
                        }
                    }
                    .font(isCompact ? .caption : .body)
                    .frame(width: isCompact ? 34 : nil, alignment: .trailing)
                    .fixedSize()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding()
                VStack(alignment: .leading, spacing: isCompact ? 2 : 4) {
                    Text("Terminal")
                        .font(isCompact ? .body.weight(.semibold) : .headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.leading, isCompact ? -10 : 0)
                        .layoutPriority(2)
                    Text(isCompact ? status : status)
                        .font(isCompact ? .caption2 : .headline)
                        .lineLimit(1)
                        .allowsTightening(true)
                        .minimumScaleFactor(0.35)
                        .layoutPriority(10)
                    HStack(spacing: isCompact ? 4 : 16) {
                        Text(isCompact ? "F: \(found)" : "Found: \(found)")
                            .font(isCompact ? .caption2.monospacedDigit() : .headline)
                            .fixedSize()
                        Text(String(format: isCompact ? "%.0f%%" : "%.0f%%", successRate * 100))
                            .font(isCompact ? .caption2.monospacedDigit() : .headline)
                            .foregroundStyle(.secondary)
                            .fixedSize()
                        Text(
                            isCompact
                            ? String(format: "%.0fms %d/%d", averageLatency * 1000, txCount, rxCount)
                            : String(format: "%.0f ms • TX %d • RX %d", averageLatency * 1000, txCount, rxCount)
                        )
                        .font(isCompact ? .caption2.monospacedDigit() : .headline)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        Button {
                            onJumpToLive()
                        } label: {
                            if isCompact {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.title2.weight(.semibold))
                            } else {
                                Text("▼ Live")
                            }
                        }
                        .font(isCompact ? .caption : .body)
                        .frame(width: isCompact ? 34 : nil, alignment: .trailing)
                        .fixedSize()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                //.padding(.vertical, 8)
            }
        }
    
}
