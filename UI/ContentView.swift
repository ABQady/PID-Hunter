//
//  ContentView.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 28/06/2026.
//

import SwiftUI

struct ContentView: View {

    @State private var header = "81F111"
    @State private var selectedMode: OBDMode = .mode01
    @State private var startPID = "0000"
    @State private var endPID = "FFFF"
    @State private var delay = 100.0

    private func applyModeDefaults(_ mode: OBDMode) {
        startPID = String(format: "%0\(mode.pidDigits)X", mode.defaultStartPID)
        endPID = String(format: "%0\(mode.pidDigits)X", mode.defaultEndPID)
    }

    var body: some View {

        GeometryReader { geo in

            if geo.size.width > 800 {

                MacLayout(
                    header: $header,
                    selectedMode: $selectedMode,
                    startPID: $startPID,
                    endPID: $endPID,
                    delay: $delay
                )

            } else {

                iPhoneLayout(
                    header: $header,
                    selectedMode: $selectedMode,
                    startPID: $startPID,
                    endPID: $endPID,
                    delay: $delay
                )

            }

        }
        .onAppear {
            applyModeDefaults(selectedMode)
        }
        .onChange(of: selectedMode) { _, newMode in
            applyModeDefaults(newMode)
        }

    }

}
