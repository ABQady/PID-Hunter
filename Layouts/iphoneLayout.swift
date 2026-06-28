//
//  iphoneLayout.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 28/06/2026.
//
import SwiftUI

struct iPhoneLayout: View {

    @Binding var header: String
    @Binding var selectedMode: Int
    @Binding var startPID: String
    @Binding var endPID: String
    @Binding var delay: Double

    var body: some View {

        TabView {

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
