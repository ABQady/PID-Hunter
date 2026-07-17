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
    let registerJumpHandler: (@escaping () -> Void) -> Void

    @State
    private var shouldAutoScroll = true
    
    
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
                return (180, 280)
            } else {
                return (360, 360)
            }
        } else {
            return (360, 650)
        }
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            let scrollToBottom = {
                withAnimation(nil) {
                    proxy.scrollTo("BOTTOM", anchor: .bottom)
                }
            }
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        let visibleLines = Array(lines.suffix(7000))
                        //let visibleLines = lines
                        ForEach(visibleLines)
                        { line in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(line.timestamp)
                                    .foregroundStyle(.secondary)
                                
                                Text(line.message)
                                    .foregroundStyle(line.style.color(for: colorScheme))
                            }
                            .font(logFont)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    Color.clear
                        .frame(height: 1)
                        .id("BOTTOM")
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
            .onChange(of: lines.count) { _, _ in
                guard shouldAutoScroll else { return }

                DispatchQueue.main.async {
                    scrollToBottom()
                }
            }
            .onScrollPhaseChange { _, phase in
                switch phase {
                case .tracking, .interacting:
                    shouldAutoScroll = false
                default:
                    break
                }
            }
            .onScrollGeometryChange(
                for: Bool.self,
                of: { geometry in
                    let bottom = geometry.contentOffset.y + geometry.containerSize.height
                    return bottom >= geometry.contentSize.height - 20
                },
                action: { _, isAtBottom in
                    if isAtBottom {
                        shouldAutoScroll = true
                    }
                }
            )
            .onAppear {
                DispatchQueue.main.async {
                    scrollToBottom()
                }

                registerJumpHandler {
                    shouldAutoScroll = true
                    DispatchQueue.main.async {
                        scrollToBottom()
                    }
                }
            }
        }
        }
}
