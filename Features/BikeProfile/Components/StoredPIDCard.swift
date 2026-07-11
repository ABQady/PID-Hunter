//
//  StoredPIDCard.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 11/07/2026.
//
import SwiftUI
import UIKit

struct StoredPIDCard: View {

    let key: DiscoveryKey
    let knowledge: BikeKnowledge

    var body: some View {

        VStack(alignment: .leading, spacing: 12) {
            // Header row: request and classification capsule
            HStack(alignment: .top) {
                Text(key.request)
                    .font(.headline.monospaced())
                Spacer()
                Label {
                    Text(knowledge.classification.title)
                        .font(.caption.weight(.semibold))
                } icon: {
                    Image(systemName: knowledge.classification.icon)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(knowledge.classification.color.opacity(0.15))
                .clipShape(Capsule())
                .foregroundStyle(knowledge.classification.color)
            }

            // Info grid: Header, Mode, Payload
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Header")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(key.header)
                        .font(.footnote.monospaced())
                }
                GridRow {
                    Text("Mode")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(key.mode)
                        .font(.footnote.monospaced())
                }
                GridRow {
                    Text("Payload")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(cleanResponsePayload)
                            .font(.footnote.monospaced())
                            .multilineTextAlignment(.trailing)

                        if let decoded = decodedPayload {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Decoded")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Text(decoded)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.trailing)
                            }
                            .padding(.top, 6)
                        }
                    }
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = cleanResponsePayload
                        } label: {
                            Label("Copy Payload", systemImage: "doc.on.doc")
                        }
                    }
                }
            }

            // Raw response, collapsible
            if !knowledge.lastResponse.isEmpty {
                DisclosureGroup("Raw Response") {
                    Text(knowledge.lastResponse)
                        .font(.footnote.monospaced())
                        .padding(.top, 2)
                }
            }

            // Metrics chips
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "scope")
                    Text("\(knowledge.hitCount)")
                }
                .padding(8)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                HStack(spacing: 4) {
                    Image(systemName: "timer")
                    Text("\(Int(knowledge.averageLatency * 1000)) ms")
                }
                .padding(8)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            // Optional notes
            let notesText = String(describing: knowledge.notes)
            if !notesText.isEmpty && notesText != "[]" {
                Divider()
                Text(notesText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.quaternary))

    }

    private var decodedPayload: String? {
        let payload = cleanResponsePayload

        guard payload != "—", payload.count.isMultiple(of: 2) else {
            return nil
        }

        var bytes: [UInt8] = []
        bytes.reserveCapacity(payload.count / 2)

        var index = payload.startIndex
        while index < payload.endIndex {
            let next = payload.index(index, offsetBy: 2)
            guard let byte = UInt8(payload[index..<next], radix: 16) else {
                return nil
            }
            bytes.append(byte)
            index = next
        }

        guard let string = String(bytes: bytes, encoding: .ascii) else {
            return nil
        }

        let printable = String(
            string.unicodeScalars.filter {
                $0.isASCII && !CharacterSet.controlCharacters.contains($0)
            }
        )
        return printable.isEmpty ? nil : printable
    }

    private var cleanResponsePayload: String {
        guard !knowledge.lastResponse.isEmpty else {
            return "—"
        }

        guard
            !knowledge.lastResponse.isEmpty,
            let mode = OBDMode(rawValue: key.mode)
        else {
            return "—"
        }

        return mode.payload(
            from: knowledge.lastResponse,
            request: key.request
        )
    }

}
