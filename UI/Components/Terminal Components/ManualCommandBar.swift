//
//  ManualCommandBar.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 04/07/2026.
//

import SwiftUI

struct ManualCommandBar: View {

    @Binding var manualCommand: String
    @FocusState.Binding var commandFieldFocused: Bool

    let send: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Manual command", text: $manualCommand)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .onSubmit(send)
                .focused($commandFieldFocused)
                .submitLabel(.send)

            Button("Send") {
                send()
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                manualCommand
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty
            )
        }
        .padding()
        .onTapGesture {
            commandFieldFocused = false
        }
    }
}

