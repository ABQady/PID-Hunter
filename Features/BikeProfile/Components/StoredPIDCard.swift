//
//  StoredPIDCard.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 11/07/2026.
//
import SwiftUI
import UIKit

struct StoredPIDCard: View {

    let record: DiscoveryRecord
    var partialResponsesOnly = false
    var isSelectionMode = false
    var isSelected = false
    var onTap: (() -> Void)? = nil

    var body: some View {

        VStack(alignment: .leading, spacing: 12) {
            // Header row: request and classification capsule
            HStack(alignment: .top) {
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        .font(.title3)
                }
                Text(record.request)
                    .font(.headline.monospaced())
                Spacer()
                Label {
                    Text(record.classification.title)
                        .font(.caption.weight(.semibold))
                } icon: {
                    Image(systemName: record.classification.icon)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(record.classification.color.opacity(0.15))
                .clipShape(Capsule())
                .foregroundStyle(record.classification.color)
            }

            // Info grid: Header, Mode, Payload
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Header")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(record.header)
                        .font(.footnote.monospaced())
                }
                GridRow {
                    Text("Mode")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(record.mode)
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
            if !record.response.isEmpty {
                DisclosureGroup("Raw Response") {
                    Text(record.response)
                        .font(.footnote.monospaced())
                        .padding(.top, 2)
                }
            }

            // Metrics chips
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "scope")
                    Text("\(record.hitCount)")
                }
                .padding(8)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                HStack(spacing: 4) {
                    Image(systemName: "timer")
                    Text("\(Int(record.averageLatency * 1000)) ms")
                }
                .padding(8)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            // Compact status badges for partial responses view
            if partialResponsesOnly {
                HStack(spacing: 8) {

                    Label(
                        record.classification == .positive
                            ? "Confirmed Positive"
                            : "Confirmed Negative",
                        systemImage: record.classification == .positive
                            ? "checkmark.circle.fill"
                            : "xmark.circle.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        (record.classification == .positive
                            ? Color.green
                            : Color.red)
                            .opacity(0.15)
                    )
                    .foregroundStyle(
                        record.classification == .positive
                            ? Color.green
                            : Color.red
                    )
                    .clipShape(Capsule())

                    Spacer()
                }
            }

            // Optional notes
            let notesText = String(describing: record.notes)
            if !notesText.isEmpty && notesText != "[]" {
                Divider()
                Text(notesText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background {
            if isSelected {
                Color.accentColor.opacity(0.12)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.gray.opacity(0.25),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode {
                onTap?()
            }
        }

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
        guard !record.response.isEmpty else {
            return "—"
        }

        guard
            !record.response.isEmpty,
            let mode = OBDMode(rawValue: record.mode)
        else {
            return "—"
        }

        return mode.payload(
            from: record.response,
            request: record.request
        )
    }

}
