//
//  StorageSearchBar.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 15/07/2026.
//

import SwiftUI

struct StorageSearchBar: View {

    @Binding var text: String
    var placeholder: String
    var isFocused: FocusState<Bool>.Binding?
    var onSubmit: () -> Void

    init(
        text: Binding<String>,
        placeholder: String = "Search files and folders",
        isFocused: FocusState<Bool>.Binding? = nil,
        onSubmit: @escaping () -> Void = {}
    ) {
        self._text = text
        self.placeholder = placeholder
        self.isFocused = isFocused
        self.onSubmit = onSubmit
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            Group {
                if let isFocused {
                    TextField(placeholder, text: $text)
                        .focused(isFocused)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onSubmit(onSubmit)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }
}

#Preview {
    StorageSearchBar(text: .constant("NHX"))
        .padding()
}
