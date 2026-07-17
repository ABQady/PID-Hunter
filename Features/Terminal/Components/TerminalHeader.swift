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
        
        Group {
            if isCompact {
                HStack(spacing: 4) {
                    Text("Terminal")
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.leading, -10)
                        .layoutPriority(2)
                    Text(status)
                        .font(.caption2)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("F: \(found)")
                        .font(.caption2.monospacedDigit())
                    Text(String(format: "%.0f%%", successRate * 100))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0fms %d/%d", averageLatency * 1000, txCount, rxCount))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Button {
                        onJumpToLive()
                    } label: {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title2.weight(.semibold))
                    }
                    .font(.caption)
                    .frame(width: 34, alignment: .trailing)
                    .layoutPriority(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                //.padding(.horizontal)
                .padding(.horizontal)
                .padding(.vertical, 6)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) {
                        Text("Terminal")
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.leading, 0)
                            .layoutPriority(2)
                        Spacer()
                        Text(status)
                            .font(.headline)
                            .lineLimit(1)
                            .allowsTightening(true)
                            .minimumScaleFactor(0.35)
                            .layoutPriority(10)
                        Spacer()
                        Text("Found: \(found)")
                            .font(.headline)
                            .fixedSize()
                        Text(String(format: "%.0f%%", successRate * 100))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .fixedSize()
                        Spacer()
                        Text(String(format: "%.0f ms • TX %d • RX %d", averageLatency * 1000, txCount, rxCount))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .fixedSize()
                        Spacer()
                        Button {
                            onJumpToLive()
                        } label: {
                            Text("▼ Live")
                        }
                        .font(.body)
                        .frame(width: nil, alignment: .trailing)
                        .fixedSize()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Terminal")
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.leading, 0)
                            .layoutPriority(2)
                        Text(status)
                            .font(.headline)
                            .lineLimit(1)
                            .allowsTightening(true)
                            .minimumScaleFactor(0.35)
                            .layoutPriority(10)
                        HStack(spacing: 16) {
                            Text("Found: \(found)")
                                .font(.headline)
                                .fixedSize()
                            Text(String(format: "%.0f%%", successRate * 100))
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .fixedSize()
                            Text(String(format: "%.0f ms • TX %d • RX %d", averageLatency * 1000, txCount, rxCount))
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .fixedSize()
                            Button {
                                onJumpToLive()
                            } label: {
                                Text("▼ Live")
                            }
                            .font(.body)
                            .frame(width: nil, alignment: .trailing)
                            .fixedSize()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                }
            }
        }
        
    }
}
