//
//  StorageUsageCard.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 15/07/2026.
//

import SwiftUI

struct StorageUsageCard: View {

    struct StorageUsage {
        enum Location {
            case profiles
            case logs
            case cache
        }
        let profiles: Int64
        let logs: Int64
        let cache: Int64

        var total: Int64 {
            profiles + logs + cache
        }
    }

    let storage: StorageUsage
    let openLocation: (StorageUsage.Location) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Storage Usage", systemImage: "internaldrive")
                .font(.headline)

            VStack(spacing: 12) {
                Button {
                    openLocation(.profiles)
                } label: {
                    storageTile(
                        title: "Profiles",
                        subtitle: "Bike Profiles & JSON",
                        value: formattedSize(storage.profiles),
                        systemImage: "shippingbox.fill",
                        tint: .blue
                    )
                }
                .buttonStyle(.plain)

                Button {
                    openLocation(.logs)
                } label: {
                    storageTile(
                        title: "Logs",
                        subtitle: "Scan Logs & CSV Exports",
                        value: formattedSize(storage.logs),
                        systemImage: "doc.text.fill",
                        tint: .orange
                    )
                }
                .buttonStyle(.plain)

                Button {
                    openLocation(.cache)
                } label: {
                    storageTile(
                        title: "Cache",
                        subtitle: "Temporary Files",
                        value: formattedSize(storage.cache),
                        systemImage: "bolt.fill",
                        tint: .green
                    )
                }
                .buttonStyle(.plain)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total Storage")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(formattedSize(storage.total))
                            .font(.title3.monospacedDigit().bold())
                    }

                    Spacer()

                    Image(systemName: "externaldrive.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
                .padding()
                .background(.quaternary.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func formattedSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    @ViewBuilder
    private func storageTile(
        title: String,
        subtitle: String,
        value: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(tint.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(value)
                .font(.headline.monospacedDigit())
        }
        .padding()
        .background(.quaternary.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    StorageUsageCard(
        storage: .init(
            profiles: 553 * 1024,
            logs: 7_700_000,
            cache: 592 * 1024
        ),
        openLocation: { _ in }
    )
}
