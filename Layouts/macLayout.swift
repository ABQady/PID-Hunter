//
//  macLayout.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 28/06/2026.
//
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct MacLayout: View {
    
    private enum Layout {
        static let terminalPreferredWidth: CGFloat = 600
        static let resultsPreferredWidth: CGFloat = 400
        static let dualPaneWidth: CGFloat = terminalPreferredWidth + resultsPreferredWidth
        static let sidebarShowWidth: CGFloat = 1550
        static let sidebarHideWidth: CGFloat = 1450
    }
    
    @Binding var header: String
    @Binding var selectedMode: Int
    @Binding var startPID: String
    @Binding var endPID: String
    @Binding var delay: Double
    
    @State private var visibility: NavigationSplitViewVisibility = .detailOnly
    @State private var lastSidebarExpanded = false
    @State private var windowWidth: CGFloat = 0
    
    private func updateWindowWidth() {
#if canImport(UIKit)
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let window = scene.windows.first
        else { return }
        
        let width = window.bounds.width
        guard width != windowWidth else { return }
        
        windowWidth = width
        
        let target: NavigationSplitViewVisibility
        if lastSidebarExpanded {
            target = width <= Layout.sidebarHideWidth ? .detailOnly : .all
        } else {
            target = width >= Layout.sidebarShowWidth ? .all : .detailOnly
        }
        
        let expanded = (target == .all)
        guard expanded != lastSidebarExpanded else { return }
        
        lastSidebarExpanded = expanded
        if visibility != target {
            visibility = target
        }
#endif
    }
    
    var body: some View {
        
        NavigationSplitView(columnVisibility: $visibility) {
            
            SettingsView(
                header: $header,
                selectedMode: $selectedMode,
                startPID: $startPID,
                endPID: $endPID,
                delay: $delay
            )
            
        } detail: {
            GeometryReader { proxy in
                let availableWidth = proxy.size.width
                
                Group {
                    if availableWidth >= Layout.dualPaneWidth {
                        HStack(spacing: 0) {
                            TerminalView(
                                selectedMode: $selectedMode,
                                header: $header,
                                startPID: $startPID,
                                endPID: $endPID
                            )
                            .frame(maxHeight: .infinity)
                            .layoutPriority(1)

                            Divider()

                            ResultsView()
                                .frame(width: Layout.resultsPreferredWidth)
                                .frame(maxHeight: .infinity)
                        }
                        .frame(maxWidth: .infinity,
                               maxHeight: .infinity)
                        .frame(minWidth: Layout.dualPaneWidth)
                    } else {
                        TabView {
                            TerminalView(
                                selectedMode: $selectedMode,
                                header: $header,
                                startPID: $startPID,
                                endPID: $endPID
                            )
                            .tabItem {
                                Label("Terminal", systemImage: "terminal")
                            }

                            ResultsView()
                                .tabItem {
                                    Label("Results", systemImage: "list.bullet.rectangle")
                                }
                        }
                    }
                }
                .onAppear {
                    visibility = .detailOnly
                    lastSidebarExpanded = false
                    updateWindowWidth()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIWindow.didBecomeVisibleNotification)) { _ in
                    updateWindowWidth()
                }
                .onChange(of: proxy.size) { _, _ in
                    updateWindowWidth()
                }
            }
        }
        
    }
}
