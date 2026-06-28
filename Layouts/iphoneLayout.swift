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

    var body: some View {

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
