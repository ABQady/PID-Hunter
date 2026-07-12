//
//  iphoneLayout.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 28/06/2026.
//
import SwiftUI
import UIKit

struct iPhoneLayout: View {

    @Binding var header: String
    @Binding var selectedMode: OBDMode
    @Binding var startPID: String
    @Binding var endPID: String
    @Binding var delay: Double

    @State private var selectedTab = 1
    @State private var terminalViewModel = TerminalViewModel()

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            if isLandscape {
                HStack(spacing: 10) {
                    TerminalView(
                        viewModel: terminalViewModel,
                        selectedMode: $selectedMode,
                        header: $header,
                        startPID: $startPID,
                        endPID: $endPID
                    )
                    .frame(maxWidth: .infinity)

                    ResultsView()
                        .frame(width: min(geometry.size.width * 0.38, 360))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 8)
            } else {
                TabView(selection: $selectedTab) {
                    SettingsView(
                        header: $header,
                        selectedMode: $selectedMode,
                        startPID: $startPID,
                        endPID: $endPID,
                        delay: $delay
                    )
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(0)

                    TerminalView(
                        viewModel: terminalViewModel,
                        selectedMode: $selectedMode,
                        header: $header,
                        startPID: $startPID,
                        endPID: $endPID
                    )
                    .tabItem {
                        Label("Terminal", systemImage: "terminal")
                    }
                    .tag(1)

                    ResultsView()
                        .tabItem {
                            Label("Results", systemImage: "list.bullet.rectangle")
                        }
                        .tag(2)
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .task {
            terminalViewModel.start()
        }
        .onDisappear {
            terminalViewModel.stop()
        }
    }

}
