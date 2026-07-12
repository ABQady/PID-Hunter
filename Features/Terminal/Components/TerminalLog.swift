//
//  TerminalLog.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 04/07/2026.
//
import SwiftUI


struct TerminalLog: View {
    @Environment(\.colorScheme)
    private var colorScheme
    
    @Environment(\.verticalSizeClass)
    private var verticalSizeClass
    
    let lines: [LogLine]
    let isCompact: Bool

    private var logFont: Font {
        .system(size: isCompact ? 10 : 11, design: .monospaced)
    }
    
    private var logBackground: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.18)
            : Color(uiColor: .secondarySystemBackground)
    }

    private var terminalHeight: (min: CGFloat, max: CGFloat) {
        if isCompact {
            if verticalSizeClass == .compact {
                return (180, 220)
            } else {
                return (320, 320)
            }
        } else {
            return (360, 650)
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(lines.suffix(isCompact ? 400 : 1200), id: \.id)
                { line in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(line.timestamp)
                            .foregroundStyle(.secondary)
                        
                        Text(line.message)
                            .foregroundStyle(line.style.color(for: colorScheme))
                    }
                    .font(logFont)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(line.id)
                }
            }
            .padding()
            .background(logBackground)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 18
                )
            )
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .defaultScrollAnchor(.bottom)
        .scrollDismissesKeyboard(.interactively)
        .frame(maxWidth: .infinity)
        .frame(minHeight: terminalHeight.min,
               maxHeight: terminalHeight.max)
    }
}
