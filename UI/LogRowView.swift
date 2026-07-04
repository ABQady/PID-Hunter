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
                .foregroundStyle(color)
        }
        .font(.system(size: 10, design: .monospaced))
    }

    private var color: Color {

        switch (line.style, colorScheme) {

        case (.tx, .light):
            return Color(red: 0.00, green: 0.28, blue: 0.82)
        case (.tx, .dark):
            return .cyan

        case (.rx, .light):
            return Color(red: 0.00, green: 0.42, blue: 0.08)
        case (.rx, .dark):
            return .green

        case (.info, .light):
            return .black
        case (.info, .dark):
            return .white

        case (.success, .light):
            return Color(red: 0.00, green: 0.48, blue: 0.12)
        case (.success, .dark):
            return .mint

        case (.warning, .light):
            return Color(red: 0.72, green: 0.36, blue: 0.00)
        case (.warning, .dark):
            return .orange

        case (.error, .light):
            return Color(red: 0.75, green: 0.00, blue: 0.00)
        case (.error, .dark):
            return .red

        case (.debug, .light):
            return Color(red: 0.22, green: 0.22, blue: 0.24)
        case (.debug, .dark):
            return .gray
        }

    }
}
