//
//  ContentView.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 28/06/2026.
//

import SwiftUI

struct ContentView: View {

    @State private var header = "81F111"
    @State private var selectedMode = 1
    @State private var startPID = "0000"
    @State private var endPID = "FFFF"
    @State private var delay = 100.0

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

    }

}
