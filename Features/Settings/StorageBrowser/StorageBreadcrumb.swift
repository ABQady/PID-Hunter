//
//  StorageBreadcrumb.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 15/07/2026.
//

import SwiftUI

struct StorageBreadcrumb: View {

    let components: [String]
    let onSelect: (Int) -> Void
    let showsBackground: Bool
    let currentIndex: Int?

    init(
        components: [String],
        showsBackground: Bool = true,
        currentIndex: Int? = nil,
        onSelect: @escaping (Int) -> Void
    ) {
        self.components = components
        self.showsBackground = showsBackground
        self.currentIndex = currentIndex
        self.onSelect = onSelect
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(components.enumerated()), id: \.offset) { index, component in

                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Button {
                        onSelect(index)
                    } label: {
                        Text(component)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                if currentIndex == index {
                                    Capsule()
                                        .fill(Color.accentColor.opacity(0.15))
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background {
            if showsBackground {
                Rectangle()
                    .fill(.thinMaterial)
            }
        }
    }
}

#Preview {
    StorageBreadcrumb(
        components: [
            "Storage",
            "Application Support",
            "Bike Profiles",
            "SYM"
        ],
        onSelect: { _ in }
    )
}
