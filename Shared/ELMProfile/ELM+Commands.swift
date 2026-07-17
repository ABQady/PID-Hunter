//
//  ELM+Commands.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 17/07/2026.
//

import Foundation


enum ELMCapability: String, Codable, Hashable {
    case firmware
    case deviceIdentifier
    case deviceDescription
    case voltage
    case protocolDescription
    case protocolNumber
}


enum ELMCommandCategory: String, CaseIterable, Codable {
    case general
    case formatting
    case protocolControl
    case timing
    case headers
    case can
    case iso
    case monitoring
    case programmableParameters
    case memory
    case miscellaneous
}


enum ELMSupportLevel: String, CaseIterable, Codable {
    case standard
    case optional
    case vendorSpecific
    case deprecated
}

enum ELMSafetyLevel: String, CaseIterable, Codable {
    case safe
    case caution
    case dangerous
}

enum ELMParameterFormat: Hashable, Codable {
    case none
    case text
    case hex8
    case hex16
    case hex24
    case hex32
    case protocolNumber
    case custom(String)
}

enum ELMResponsePattern: Hashable, Codable {
    case ok
    case error
    case questionMark
    case contains(String)
    case startsWith(String)
    case exact(String)
    case regex(String)
}

struct ELMCommand: Identifiable, Hashable, Codable {
    var id: String { command }

    let command: String
    let name: String
    let description: String
    let parameterFormat: ELMParameterFormat
    let example: String?
    let supportLevel: ELMSupportLevel
    let safetyLevel: ELMSafetyLevel
    let expectedResponses: Set<ELMResponsePattern>
    let aliases: [String]
    let category: ELMCommandCategory
    let capability: ELMCapability?

    var displayName: String {
        if let capability {
            switch capability {
            case .firmware:
                return "Reading firmware"
            case .deviceIdentifier:
                return "Reading device identifier"
            case .deviceDescription:
                return "Reading device description"
            case .voltage:
                return "Reading battery voltage"
            case .protocolDescription:
                return "Detecting protocol"
            case .protocolNumber:
                return "Reading protocol number"
            }
        }

        switch category {
        case .general:
            return name
        case .formatting:
            return "Testing formatting commands"
        case .protocolControl:
            return "Testing protocol commands"
        case .timing:
            return "Testing timing commands"
        case .headers:
            return "Testing header commands"
        case .can:
            return "Testing CAN commands"
        case .iso:
            return "Testing ISO commands"
        case .monitoring:
            return "Testing monitoring commands"
        case .programmableParameters:
            return "Testing programmable parameters"
        case .memory:
            return "Testing memory commands"
        case .miscellaneous:
            return "Testing miscellaneous commands"
        }
    }

    var isParameterized: Bool {
        parameterFormat != .none
    }

    var isStandard: Bool {
        supportLevel == .standard
    }

    var isOptional: Bool {
        supportLevel == .optional
    }

    var isVendorSpecific: Bool {
        supportLevel == .vendorSpecific
    }

    var isDeprecated: Bool {
        supportLevel == .deprecated
    }

    func matches(_ response: String) -> Bool {
        let response = response.uppercased()

        return expectedResponses.contains { pattern in
            pattern.matches(response)
        }
    }
}

private extension ELMResponsePattern {

    func matches(_ response: String) -> Bool {
        switch self {
        case .ok:
            return response.contains("OK")

        case .error:
            return response.contains("ERROR")

        case .questionMark:
            return response.contains("?")

        case .contains(let value):
            return response.contains(value.uppercased())

        case .startsWith(let value):
            return response.hasPrefix(value.uppercased())

        case .exact(let value):
            return response.trimmingCharacters(in: .whitespacesAndNewlines) == value.uppercased()

        case .regex(let pattern):
            return response.range(of: pattern, options: .regularExpression) != nil
        }
    }
}

enum ELMCommands {

    static let all: [ELMCommand] = [
        .init(command: "ATZ", name: "Reset", description: "Reset ELM327", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: ["RESET"], category: .general, capability: nil),
        .init(command: "ATWS", name: "Warm Start", description: "Warm reset", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: ["WARM_START"], category: .general, capability: nil),
        .init(command: "ATD", name: "Defaults", description: "Restore defaults", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .dangerous, expectedResponses: [.ok], aliases: [], category: .general, capability: nil),
        .init(command: "ATI", name: "Identify", description: "Firmware version", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.contains("ELM327"), .contains("OBD"), .contains("STN")], aliases: ["IDENTIFY"], category: .general, capability: .firmware),
        .init(command: "AT@1", name: "Device Description", description: "Read device description", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .general, capability: .deviceDescription),
        .init(command: "AT@2", name: "Device Identifier", description: "Read device identifier", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .general, capability: .deviceIdentifier),
        .init(command: "AT@3", name: "Store Identifier", description: "Store device identifier", parameterFormat: .text, example: "AT@3MyID", supportLevel: .standard, safetyLevel: .dangerous, expectedResponses: [.ok], aliases: [], category: .general, capability: nil),
        .init(command: "ATRV", name: "Read Voltage", description: "Battery voltage", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.regex("\\d+\\.\\d+V")], aliases: ["READ_VOLTAGE"], category: .general, capability: .voltage),
        .init(command: "ATIGN", name: "Ignition Status", description: "Read ignition input", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.exact("ON"), .exact("OFF")], aliases: [], category: .general, capability: nil),
        .init(command: "ATE0", name: "Echo Off", description: "Disable echo", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .formatting, capability: nil),
        .init(command: "ATE1", name: "Echo On", description: "Enable echo", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .formatting, capability: nil),
        .init(command: "ATL0", name: "Linefeeds Off", description: "Disable LF", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .formatting, capability: nil),
        .init(command: "ATL1", name: "Linefeeds On", description: "Enable LF", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .formatting, capability: nil),
        .init(command: "ATS0", name: "Spaces Off", description: "Disable spaces", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .formatting, capability: nil),
        .init(command: "ATS1", name: "Spaces On", description: "Enable spaces", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .formatting, capability: nil),
        .init(command: "ATH0", name: "Headers Off", description: "Hide headers", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: ["HEADERS_OFF"], category: .headers, capability: nil),
        .init(command: "ATH1", name: "Headers On", description: "Show headers", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: ["HEADERS_ON"], category: .headers, capability: nil),
        .init(command: "ATCAF0", name: "Auto Formatting Off", description: "Disable CAN auto formatting", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .formatting, capability: nil),
        .init(command: "ATCAF1", name: "Auto Formatting On", description: "Enable CAN auto formatting", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .formatting, capability: nil),
        .init(command: "ATAL", name: "Allow Long Messages", description: "Enable long messages", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .formatting, capability: nil),
        .init(command: "ATNL", name: "Normal Length", description: "Normal message length", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .formatting, capability: nil),
        .init(command: "ATDP", name: "Describe Protocol", description: "Current protocol", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.contains("AUTO"), .contains("ISO"), .contains("CAN"), .contains("SAE"), .contains("J1850"), .contains("PWM"), .contains("VPW")], aliases: ["DESCRIBE_PROTOCOL"], category: .protocolControl, capability: .protocolDescription),
        .init(command: "ATDPN", name: "Protocol Number", description: "Current protocol number", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.contains("A"), .contains("1"), .contains("2"), .contains("3"), .contains("4"), .contains("5"), .contains("6"), .contains("7"), .contains("8"), .contains("9")], aliases: [], category: .protocolControl, capability: .protocolNumber),
        .init(command: "ATSP", name: "Set Protocol", description: "Select protocol", parameterFormat: .protocolNumber, example: "ATSP0", supportLevel: .standard, safetyLevel: .caution, expectedResponses: [.ok], aliases: [], category: .protocolControl, capability: nil),
        .init(command: "ATTP", name: "Try Protocol", description: "Temporarily try protocol", parameterFormat: .protocolNumber, example: "ATTP1", supportLevel: .standard, safetyLevel: .caution, expectedResponses: [.ok], aliases: [], category: .protocolControl, capability: nil),
        .init(command: "ATST", name: "Set Timeout", description: "Set timeout", parameterFormat: .hex8, example: "ATST64", supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .timing, capability: nil),
        .init(command: "ATAT0", name: "Adaptive Timing Off", description: "Disable adaptive timing", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .timing, capability: nil),
        .init(command: "ATAT1", name: "Adaptive Timing Auto1", description: "Adaptive timing mode 1", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .timing, capability: nil),
        .init(command: "ATAT2", name: "Adaptive Timing Auto2", description: "Adaptive timing mode 2", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .timing, capability: nil),
        .init(command: "ATSH", name: "Set Header", description: "Set transmit header", parameterFormat: .hex16, example: "ATSH7E0", supportLevel: .standard, safetyLevel: .caution, expectedResponses: [.ok], aliases: [], category: .headers, capability: nil),
        .init(command: "ATCRA", name: "Receive Address", description: "Set receive filter", parameterFormat: .hex16, example: "ATCRA7DF", supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .headers, capability: nil),
        .init(command: "ATFI", name: "Fast Init", description: "ISO fast init", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok, .startsWith("BUS INIT"), .contains("BUS INIT: OK"), .error, .questionMark], aliases: [], category: .iso, capability: nil),
        .init(command: "ATSI", name: "Slow Init", description: "ISO slow init", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok, .startsWith("BUS INIT"), .contains("BUS INIT: OK"), .error, .questionMark], aliases: [], category: .iso, capability: nil),
        .init(command: "ATMA", name: "Monitor All", description: "Monitor all traffic", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .monitoring, capability: nil),
        .init(command: "ATMR", name: "Monitor Receiver", description: "Monitor receiver", parameterFormat: .hex8, example: "ATMR11", supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .monitoring, capability: nil),
        .init(command: "ATMT", name: "Monitor Transmitter", description: "Monitor transmitter", parameterFormat: .hex8, example: "ATMT11", supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .monitoring, capability: nil),
        .init(command: "ATCFC0", name: "Flow Control Off", description: "Disable flow control", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .can, capability: nil),
        .init(command: "ATCFC1", name: "Flow Control On", description: "Enable flow control", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .can, capability: nil),
        .init(command: "ATPP", name: "Programmable Parameter", description: "Configure programmable parameter", parameterFormat: .custom("xx y"), example: "ATPP 01 ON", supportLevel: .standard, safetyLevel: .dangerous, expectedResponses: [.ok], aliases: [], category: .programmableParameters, capability: nil),
        .init(command: "ATM0", name: "Memory Off", description: "Disable memory", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .caution, expectedResponses: [.ok], aliases: [], category: .memory, capability: nil),
        .init(command: "ATM1", name: "Memory On", description: "Enable memory", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .caution, expectedResponses: [.ok], aliases: [], category: .memory, capability: nil),
        .init(command: "ATPC", name: "Protocol Close", description: "Close current protocol", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .miscellaneous, capability: nil),
        .init(command: "ATLP", name: "Low Power", description: "Enter low power mode", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .caution, expectedResponses: [.ok], aliases: [], category: .miscellaneous, capability: nil),

        // --- Additional canonical AT commands ---
        // General
        .init(command: "ATAR", name: "Auto Receive", description: "Automatically receive", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .general, capability: nil),
        .init(command: "ATBD", name: "Set Baud Rate Divisor", description: "Set RS232 baud rate divisor", parameterFormat: .hex8, example: "ATBD 68", supportLevel: .standard, safetyLevel: .caution, expectedResponses: [.ok], aliases: [], category: .general, capability: nil),
        .init(command: "ATBI", name: "Bypass Initialization", description: "Bypass ISO initialization", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .caution, expectedResponses: [.ok], aliases: [], category: .iso, capability: nil),
        .init(command: "ATBRD", name: "Baud Rate Detect", description: "Detect baud rate", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .general, capability: nil),
        .init(command: "ATBRT", name: "Baud Rate Timing", description: "Set baud rate timing", parameterFormat: .hex8, example: "ATBRT 0F", supportLevel: .standard, safetyLevel: .caution, expectedResponses: [.ok], aliases: [], category: .general, capability: nil),
        // CAN
        .init(command: "ATCEA", name: "CAN Extended Address", description: "Set CAN extended addressing", parameterFormat: .hex8, example: "ATCEA 80", supportLevel: .standard, safetyLevel: .caution, expectedResponses: [.ok], aliases: [], category: .can, capability: nil),
        .init(command: "ATCF", name: "CAN Filter", description: "Set CAN ID filter", parameterFormat: .hex24, example: "ATCF 123456", supportLevel: .standard, safetyLevel: .caution, expectedResponses: [.ok], aliases: [], category: .can, capability: nil),
        .init(command: "ATCM", name: "CAN Mask", description: "Set CAN ID mask", parameterFormat: .hex24, example: "ATCM 123456", supportLevel: .standard, safetyLevel: .caution, expectedResponses: [.ok], aliases: [], category: .can, capability: nil),
        .init(command: "ATCP", name: "CAN Priority", description: "Set CAN priority", parameterFormat: .hex8, example: "ATCP 08", supportLevel: .standard, safetyLevel: .caution, expectedResponses: [.ok], aliases: [], category: .can, capability: nil),
        .init(command: "ATCSM", name: "CAN Silent Monitoring", description: "CAN silent monitoring mode", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .can, capability: nil),
        // CAN Flow Control
        .init(command: "ATFCSD", name: "Flow Control Data", description: "Set CAN flow control data", parameterFormat: .custom("xx xx xx"), example: "ATFCSD 11 22 33", supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .can, capability: nil),
        .init(command: "ATFCSH", name: "Flow Control Header", description: "Set CAN flow control header", parameterFormat: .hex16, example: "ATFCSH 7E0", supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .can, capability: nil),
        .init(command: "ATFCSM", name: "Flow Control Mode", description: "Set CAN flow control mode", parameterFormat: .protocolNumber, example: "ATFCSM 1", supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .can, capability: nil),
        // ISO
        .init(command: "ATIB", name: "ISO Baud Rate", description: "Set ISO baud rate", parameterFormat: .hex8, example: "ATIB 96", supportLevel: .standard, safetyLevel: .caution, expectedResponses: [.ok], aliases: [], category: .iso, capability: nil),
        .init(command: "ATIIA", name: "ISO Init Address", description: "Set ISO initial address", parameterFormat: .hex8, example: "ATIIA 13", supportLevel: .standard, safetyLevel: .caution, expectedResponses: [.ok], aliases: [], category: .iso, capability: nil),
        .init(command: "ATKW", name: "ISO Key Word", description: "Set ISO keyword", parameterFormat: .hex16, example: "ATKW 1234", supportLevel: .standard, safetyLevel: .caution, expectedResponses: [.ok], aliases: [], category: .iso, capability: nil),
        .init(command: "ATSW", name: "ISO Slow Wakeup", description: "ISO slow wakeup", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .iso, capability: nil),
        // Timing
        .init(command: "ATTA", name: "Test Address", description: "Set test address", parameterFormat: .hex8, example: "ATTA 33", supportLevel: .standard, safetyLevel: .caution, expectedResponses: [.ok], aliases: [], category: .timing, capability: nil),
        .init(command: "ATWM", name: "Wakeup Message", description: "Send wakeup message", parameterFormat: .custom("xx xx xx xx"), example: "ATWM 81 13 F1 81", supportLevel: .standard, safetyLevel: .caution, expectedResponses: [.ok], aliases: [], category: .timing, capability: nil),
        // Programmable Parameters
        .init(command: "ATPPFF", name: "PP Disable All", description: "Disable all programmable parameters", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .dangerous, expectedResponses: [.ok], aliases: [], category: .programmableParameters, capability: nil),
        .init(command: "ATPPxxON", name: "PP Enable", description: "Enable programmable parameter", parameterFormat: .hex8, example: "ATPP 01 ON", supportLevel: .standard, safetyLevel: .dangerous, expectedResponses: [.ok], aliases: [], category: .programmableParameters, capability: nil),
        .init(command: "ATPPxxOFF", name: "PP Disable", description: "Disable programmable parameter", parameterFormat: .hex8, example: "ATPP 01 OFF", supportLevel: .standard, safetyLevel: .dangerous, expectedResponses: [.ok], aliases: [], category: .programmableParameters, capability: nil),
        .init(command: "ATPPxxSVyy", name: "PP Set Value", description: "Set programmable parameter value", parameterFormat: .custom("xx yy"), example: "ATPP 01 SV 05", supportLevel: .standard, safetyLevel: .dangerous, expectedResponses: [.ok], aliases: [], category: .programmableParameters, capability: nil),
        // Memory
        .init(command: "ATSR", name: "Set Receive Address", description: "Set receive address", parameterFormat: .hex16, example: "ATSR 7DF", supportLevel: .standard, safetyLevel: .caution, expectedResponses: [.ok], aliases: [], category: .memory, capability: nil),
        // Miscellaneous
        .init(command: "ATFE", name: "Forget Events", description: "Forget all events", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .miscellaneous, capability: nil),
        .init(command: "ATRD", name: "Read Data", description: "Read stored data", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .safe, expectedResponses: [.ok], aliases: [], category: .miscellaneous, capability: nil),
        .init(command: "ATSD", name: "Set Data", description: "Set stored data", parameterFormat: .hex8, example: "ATSD 01", supportLevel: .standard, safetyLevel: .caution, expectedResponses: [.ok], aliases: [], category: .miscellaneous, capability: nil),
        .init(command: "ATSP0", name: "Set Protocol Auto", description: "Set protocol to automatic", parameterFormat: .none, example: nil, supportLevel: .standard, safetyLevel: .caution, expectedResponses: [.ok], aliases: [], category: .protocolControl, capability: nil),
        // Clone/vendor-specific or deprecated commands
        .init(command: "ATINFO", name: "Device Info", description: "Vendor-specific: Info command", parameterFormat: .none, example: nil, supportLevel: .vendorSpecific, safetyLevel: .safe, expectedResponses: [], aliases: [], category: .general, capability: nil),
        .init(command: "ATVER", name: "Version", description: "Vendor-specific: Firmware version", parameterFormat: .none, example: nil, supportLevel: .vendorSpecific, safetyLevel: .safe, expectedResponses: [], aliases: [], category: .general, capability: nil),
        .init(command: "ATFW", name: "Firmware", description: "Vendor-specific: Firmware info", parameterFormat: .none, example: nil, supportLevel: .vendorSpecific, safetyLevel: .safe, expectedResponses: [], aliases: [], category: .general, capability: nil),
        .init(command: "ATFIRM", name: "Firmware Version", description: "Vendor-specific: Firmware version", parameterFormat: .none, example: nil, supportLevel: .vendorSpecific, safetyLevel: .safe, expectedResponses: [], aliases: [], category: .general, capability: nil),
        .init(command: "ATDEBUG", name: "Debug", description: "Vendor-specific: Debug command", parameterFormat: .none, example: nil, supportLevel: .vendorSpecific, safetyLevel: .safe, expectedResponses: [], aliases: [], category: .miscellaneous, capability: nil),
        .init(command: "ATTEST", name: "Test Command", description: "Vendor-specific: Test command", parameterFormat: .none, example: nil, supportLevel: .vendorSpecific, safetyLevel: .safe, expectedResponses: [], aliases: [], category: .miscellaneous, capability: nil)
    ]

    static func commands(in category: ELMCommandCategory) -> [ELMCommand] {
        all.filter { $0.category == category }
    }

    static func command(_ value: String) -> ELMCommand? {
        all.first { $0.command.caseInsensitiveCompare(value) == .orderedSame }
    }
}

