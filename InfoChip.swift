//
//  InfoChip.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 27/06/2026.
//

import SwiftUI

struct InfoChip: View {

    let title: String
    let color: Color

    var body: some View {

        Text(title)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
