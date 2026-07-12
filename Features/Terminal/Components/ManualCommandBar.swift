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

    private var trimmedCommand: String {
        manualCommand.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(spacing: 8) {
            TextField("Manual command", text: $manualCommand)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .onSubmit(send)
                .focused($commandFieldFocused)
                .submitLabel(.send)

            Button("Send") {
                manualCommand = trimmedCommand
                send()
            }
            .buttonStyle(.borderedProminent)
            .disabled(trimmedCommand.isEmpty)
        }
        .padding()
        .onTapGesture {
            commandFieldFocused = false
        }
    }
}
