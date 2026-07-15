//
//  StorageTile.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 15/07/2026.
//

import SwiftUI

struct StorageTile: View {

    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    let detail: String?
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack {
                Spacer()
                HStack{
                    Spacer()
                    Image(systemName: icon)
                        .font(.system(size: 50, weight: .medium))
                        .foregroundStyle(iconColor)
                    Spacer()
                }
                Spacer()
            }.frame(height: 72)
            Spacer()
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            if let detail, !detail.isEmpty {
                Divider()
                HStack {
                    Spacer()
                    Text(detail)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .padding()
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var backgroundColor: Color {
        isSelected
            ? Color.accentColor.opacity(0.18)
            : Color.primary.opacity(0.04)
    }}

#Preview {
    HStack {
        StorageTile(
            icon: "folder.fill",
            iconColor: .blue,
            title: "Bike Profiles",
            subtitle: "12 items",
            detail: "2.4 MB",
            isSelected: false,
        )

        StorageTile(
            icon: "doc.text.fill",
            iconColor: .orange,
            title: "scan_2026_07_15.log",
            subtitle: "Today, 10:42",
            detail: "184 KB",
            isSelected: false,
        )
    }
    .padding()
}
