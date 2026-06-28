//
//  PIDResultCard.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 27/06/2026.
//
import SwiftUI

struct PIDResultCard: View {

    let result: ScanResult

    @State private var expanded = false

    private var payloadBytes: Int {
        let tokens = result.response.split(separator: " ")

        guard let mode = OBDMode(rawValue: result.mode) else {
            return max(tokens.count - 2, 0)
        }

        let headerBytes = mode.pidDigits == 4 ? 3 : 2
        return max(tokens.count - headerBytes, 0)
    }

    var body: some View {

        VStack(alignment: .leading, spacing: 12) {

            Button {

                withAnimation(.snappy) {
                    expanded.toggle()
                }

            } label: {

                VStack(alignment: .leading, spacing: 10) {

                    HStack {
                        Label( result.pid, systemImage: "memorychip.fill")
                        .font(.headline)

                        Spacer()

                        Image(systemName:
                            expanded
                            ? "chevron.up"
                            : "chevron.down")
                        .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(result.header)
                            .font(.caption.monospaced())

                        Spacer()

                        Text(OBDMode(rawValue: result.mode)?.title ?? "Mode \(result.mode)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(result.response)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if expanded {

                Divider()

                LabeledContent("Request") {

                    Text(result.request)
                        .font(.system(.body,
                                      design: .monospaced))
                }

                LabeledContent("Response") {

                    Text(result.response)
                        .font(.system(.body,
                                      design: .monospaced))
                        .textSelection(.enabled)
                }

                LabeledContent("Payload") {

                    Text("\(payloadBytes) bytes")
                }
                
                HStack(spacing: 6) {

                    InfoChip(
                        title: OBDMode(rawValue: result.mode)?.rawValue ?? result.mode,
                        color: .blue
                    )

                    InfoChip(
                        title: "\(payloadBytes) Bytes",
                        color: .green
                    )

                    InfoChip(
                        title: result.header,
                        color: .orange
                    )

                    Spacer()
                }

                Button {

#if os(macOS)

                    NSPasteboard.general.clearContents()

                    NSPasteboard.general.setString(
                        result.response,
                        forType: .string
                    )

#endif

                } label: {

                    Label(
                        "Copy Response",
                        systemImage: "doc.on.doc"
                    )
                }
                .buttonStyle(.bordered)

            }

        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
