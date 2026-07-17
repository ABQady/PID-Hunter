//
//  StorageRow.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 15/07/2026.
//

import SwiftUI

struct StorageRow: View {

    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    let detail: String?
    let showsChevron: Bool
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var backgroundColor: Color {
        isSelected
            ? Color.accentColor.opacity(0.18)
            : Color.primary.opacity(0.04)
    }
}

#Preview {
    VStack(spacing: 12) {
        StorageRow(
            icon: "folder.fill",
            iconColor: .blue,
            title: "Bike Profiles",
            subtitle: "12 items • Modified today",
            detail: "2.4 MB",
            showsChevron: true,
            isSelected: false
        )

        StorageRow(
            icon: "doc.text.fill",
            iconColor: .orange,
            title: "scan_2026_07_15.log",
            subtitle: "Today, 10:42",
            detail: "184 KB",
            showsChevron: false,
            isSelected: false
        )
    }
    .padding()
}
