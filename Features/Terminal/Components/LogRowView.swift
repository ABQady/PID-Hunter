//
//  LogRowView.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 04/07/2026.
//
import SwiftUI

struct LogRowView: View {

    let line: LogLine

    @Environment(\.colorScheme)
    private var colorScheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {

            Text(line.timestamp)
                .foregroundStyle(.secondary)

            Text(line.message)
                .foregroundStyle(line.style.color(for: colorScheme))
                .layoutPriority(1)
        }
    }
}
