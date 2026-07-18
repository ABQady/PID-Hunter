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
            ZStack {

                if let standardPID {
                    Text(standardPID.name)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 72)
                        .padding(.vertical, 6)
                        .allowsHitTesting(false)
                        .zIndex(0)
                }

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
                        if UIDevice.current.userInterfaceIdiom != .phone {
                            Text(record.classification.title)
                                .font(.caption.weight(.semibold))
                        }
                    } icon: {
                        Image(systemName: record.classification.icon)
                    }
                    .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .phone ? 8 : 10)
                    .padding(.vertical, 6)
                    .background(record.classification.color.opacity(0.15))
                    .clipShape(Capsule())
                    .foregroundStyle(record.classification.color)
                }
                .zIndex(1)
            }
            .frame(minHeight: 34)
            
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
                DisclosureGroup("Response") {
                    if isStandardPID,
                       let standardPID {
                        HStack() {
                            if let decoded = decodedStandardValue {
                                Spacer()
                                    Text(formattedDecodedValue(decoded))
                                        .font(.footnote.weight(.bold))
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                Spacer()
                            }
                        }
                        Divider()
                    }
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
            
            Divider()
            
            HStack {
                Label(
                    isStandardPID ? "Standard PID" : "Manufacturer Specific",
                    systemImage: isStandardPID ? "checkmark.seal.fill" : "wrench.and.screwdriver.fill"
                )
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background((isStandardPID ? Color.green : Color.orange).opacity(0.15))
                .foregroundStyle(isStandardPID ? Color.green : Color.orange)
                .clipShape(Capsule())
                
                Spacer()
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
    
    private func formattedDecodedValue(_ text: String) -> String {
        let pattern = #"-?\d+(?:\.\d+)?"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        var result = text

        for match in matches.reversed() {
            let original = nsText.substring(with: match.range)

            guard let value = Double(original) else { continue }

            let formatted = String(format: "%.2f", value)

            let range = Range(match.range, in: result)!
            result.replaceSubrange(range, with: formatted)
        }

        return result
    }
    
    private var isStandardPID: Bool {
        guard let mode = OBDMode(rawValue: record.mode),
              mode == .mode01,
              let pid = UInt8(record.request.suffix(2), radix: 16)
        else {
            return false
        }
        
        return StandardPIDDatabase.lookup(pid) != nil
    }
    
    private var standardPID: StandardPID? {
        guard let mode = OBDMode(rawValue: record.mode),
              mode == .mode01,
              let pid = UInt8(record.request.suffix(2), radix: 16)
        else {
            return nil
        }
        
        return StandardPIDDatabase.lookup(pid)
    }
    
    private var decodedStandardValue: String? {
        guard let standardPID else { return nil }

        let values = standardPID.decoder.decode(payloadBytes)
        guard !values.isEmpty else { return nil }

        return values
            .map { value in
                let unit = standardPID.unit.map { " \($0)" } ?? ""

                let displayValue: String
                switch value.value {
                case .number(let number):
                    displayValue = "\(number)\(unit)"
                case .text(let text):
                    displayValue = text
                case .bytes(let bytes):
                    displayValue = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
                case .bitmap(let bitmap):
                    displayValue = String(format: "0x%08X", bitmap)
                case .boolean(let flag):
                    displayValue = flag ? "True" : "False"
                }

                if let label = value.label {
                    return "\(label): \(displayValue)"
                }

                return displayValue
            }
            .joined(separator: "\n")
    }
    
    private var payloadBytes: [UInt8] {
        let payload = cleanResponsePayload
        guard payload != "—", payload.count.isMultiple(of: 2) else {
            return []
        }
        
        var bytes: [UInt8] = []
        var index = payload.startIndex
        
        while index < payload.endIndex {
            let next = payload.index(index, offsetBy: 2)
            guard let byte = UInt8(payload[index..<next], radix: 16) else {
                return []
            }
            bytes.append(byte)
            index = next
        }
        
        return bytes
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
