<<<<<<< HEAD
=======
//

>>>>>>> Inference
//  OBD+PID+Decoder.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 18/07/2026.
//

import Foundation


/// Describes the physical meaning of a decoded value.
///
/// This is intentionally independent from the decoding algorithm.
/// Different PIDs may share the same value kind while using different
/// formulas or byte layouts.
enum PIDValueKind: Hashable {
    // Raw and simple types
    case raw
    case binary
    case bitfield
    // Proportional/relative
    case percentage
    // Temperature/thermal
    case temperature
    // Speed/rotation
    case rotationalSpeed
    case vehicleSpeed
    // Pressure types
    case pressure
    case airPressure
    case evapPressure
    // Mass, volume, flow
    case mass
    case airflow
    case flowRate
    case fuelRate
    // Electrical
    case voltage
    case current
    case energy
    case power
    // Angles, geometry, motion
    case angle
    case acceleration
    // Fuel/air
    case fuelTrim
    case lambda
    // Time, distance, count
    case duration
    case distance
    case count
    // Status/logic
    case status
    // Miscellaneous
    case torque
    case frequency
    case concentration
    case humidity
    case gear
}

// MARK: - Protocol-Oriented PID Decoding

<<<<<<< HEAD
enum PIDValue: Hashable {
    case number(Double)
    case text(String)
    case bytes([UInt8])
    case bitmap(UInt32)
    case boolean(Bool)
}

/// A decoded value with its physical meaning.
struct PIDDecodedValue: Hashable {
    let value: PIDValue
    let kind: PIDValueKind
    let label: String?

    init(value: PIDValue, kind: PIDValueKind, label: String? = nil) {
=======
/// A decoded value with its physical meaning.
struct PIDDecodedValue: Hashable {
    let value: Double
    let kind: PIDValueKind
    let label: String?

    init(value: Double, kind: PIDValueKind, label: String? = nil) {
>>>>>>> Inference
        self.value = value
        self.kind = kind
        self.label = label
    }
<<<<<<< HEAD

    init(number: Double, kind: PIDValueKind, label: String? = nil) {
        self.init(value: .number(number), kind: kind, label: label)
    }
=======
>>>>>>> Inference
}

/// Protocol describing the kind and label of a PID value.
protocol PIDValueDescriptor {
    var kind: PIDValueKind { get }
    var label: String? { get }
}

/// Protocol for all PID decoder implementations.
protocol ProtocolPIDDecoding {
    var descriptor: PIDDecodedValue { get }
    func decode(_ bytes: [UInt8]) -> [PIDDecodedValue]
}

/// Base protocol for decoders producing multiple semantic values.
protocol MultiValuePIDDecoder: ProtocolPIDDecoding {
    static var primaryKind: PIDValueKind { get }
}

extension MultiValuePIDDecoder {
    var descriptor: PIDDecodedValue {
<<<<<<< HEAD
        PIDDecodedValue(number: 0, kind: Self.primaryKind)
=======
        PIDDecodedValue(value: 0, kind: Self.primaryKind)
>>>>>>> Inference
    }
}

/// Base protocol for single-value PID decoders.
protocol SingleValuePIDDecoder: ProtocolPIDDecoding {
    func decodeValue(_ bytes: [UInt8]) -> Double?
}

protocol NamedPIDDecoder: SingleValuePIDDecoder {
    static var descriptor: PIDDecodedValue { get }
}

extension NamedPIDDecoder {
    var descriptor: PIDDecodedValue { Self.descriptor }

    func decode(_ bytes: [UInt8]) -> [PIDDecodedValue] {
        guard let value = decodeValue(bytes) else { return [] }
<<<<<<< HEAD
        return [PIDDecodedValue(number: value,
=======
        return [PIDDecodedValue(value: value,
>>>>>>> Inference
                                kind: Self.descriptor.kind,
                                label: Self.descriptor.label)]
    }
}

// Protocol extension for helpers shared by all implementations.
extension ProtocolPIDDecoding {
    /// Helper to combine two bytes as a big-endian UInt16.
    func word(_ bytes: [UInt8]) -> UInt16? {
        guard bytes.count >= 2 else { return nil }
        return UInt16(bytes[0]) << 8 | UInt16(bytes[1])
    }
    func signedWord(_ bytes: [UInt8]) -> Int16? {
        guard let value = word(bytes) else { return nil }
        return Int16(bitPattern: value)
    }
    func firstByte(_ bytes: [UInt8]) -> UInt8? {
        bytes.first
    }

}



// MARK: - Decoder Implementations

// MARK: Basic Decoders

<<<<<<< HEAD
struct RawPIDDecoder: ProtocolPIDDecoding {
    let descriptor = PIDDecodedValue(value: .bytes([]), kind: .raw)

    func decode(_ bytes: [UInt8]) -> [PIDDecodedValue] {
        [PIDDecodedValue(value: .bytes(bytes), kind: .raw)]
=======
struct RawPIDDecoder: NamedPIDDecoder {
    static let descriptor = PIDDecodedValue(value: 0, kind: .raw)
    func decodeValue(_ bytes: [UInt8]) -> Double? {
        firstByte(bytes).map(Double.init)
>>>>>>> Inference
    }
}

struct PercentagePIDDecoder: NamedPIDDecoder {
<<<<<<< HEAD
    static let descriptor = PIDDecodedValue(number: 0, kind: .percentage)
=======
    static let descriptor = PIDDecodedValue(value: 0, kind: .percentage)
>>>>>>> Inference
    func decodeValue(_ bytes: [UInt8]) -> Double? {
        guard let a = firstByte(bytes) else { return nil }
        return Double(a) * 100.0 / 255.0
    }
}

struct TemperaturePIDDecoder: NamedPIDDecoder {
<<<<<<< HEAD
    static let descriptor = PIDDecodedValue(number: 0, kind: .temperature)
=======
    static let descriptor = PIDDecodedValue(value: 0, kind: .temperature)
>>>>>>> Inference
    func decodeValue(_ bytes: [UInt8]) -> Double? {
        guard let a = firstByte(bytes) else { return nil }
        return Double(Int(a) - 40)
    }
}

// MARK: Numeric Decoders

struct RPMPIDDecoder: NamedPIDDecoder {
<<<<<<< HEAD
    static let descriptor = PIDDecodedValue(number: 0, kind: .rotationalSpeed)
=======
    static let descriptor = PIDDecodedValue(value: 0, kind: .rotationalSpeed)
>>>>>>> Inference
    func decodeValue(_ bytes: [UInt8]) -> Double? {
        guard let value = word(bytes) else { return nil }
        return Double(value) / 4.0
    }
}

struct SpeedPIDDecoder: NamedPIDDecoder {
<<<<<<< HEAD
    static let descriptor = PIDDecodedValue(number: 0, kind: .vehicleSpeed)
=======
    static let descriptor = PIDDecodedValue(value: 0, kind: .vehicleSpeed)
>>>>>>> Inference
    func decodeValue(_ bytes: [UInt8]) -> Double? {
        firstByte(bytes).map(Double.init)
    }
}

struct TimingAdvancePIDDecoder: NamedPIDDecoder {
<<<<<<< HEAD
    static let descriptor = PIDDecodedValue(number: 0, kind: .angle)
=======
    static let descriptor = PIDDecodedValue(value: 0, kind: .angle)
>>>>>>> Inference
    func decodeValue(_ bytes: [UInt8]) -> Double? {
        guard let a = firstByte(bytes) else { return nil }
        return Double(a) / 2.0 - 64.0
    }
}

struct PressurePIDDecoder: NamedPIDDecoder {
<<<<<<< HEAD
    static let descriptor = PIDDecodedValue(number: 0, kind: .pressure)
=======
    static let descriptor = PIDDecodedValue(value: 0, kind: .pressure)
>>>>>>> Inference
    func decodeValue(_ bytes: [UInt8]) -> Double? {
        firstByte(bytes).map(Double.init)
    }
}

struct VoltagePIDDecoder: NamedPIDDecoder {
<<<<<<< HEAD
    static let descriptor = PIDDecodedValue(number: 0, kind: .voltage)
=======
    static let descriptor = PIDDecodedValue(value: 0, kind: .voltage)
>>>>>>> Inference
    func decodeValue(_ bytes: [UInt8]) -> Double? {
        guard let value = word(bytes) else { return nil }
        return Double(value) / 1000.0
    }
}

struct MAFPIDDecoder: NamedPIDDecoder {
<<<<<<< HEAD
    static let descriptor = PIDDecodedValue(number: 0, kind: .flowRate)
=======
    static let descriptor = PIDDecodedValue(value: 0, kind: .flowRate)
>>>>>>> Inference
    func decodeValue(_ bytes: [UInt8]) -> Double? {
        guard let value = word(bytes) else { return nil }
        return Double(value) / 100.0
    }
}

// MARK: Fuel Decoders

struct FuelTrimPIDDecoder: NamedPIDDecoder {
<<<<<<< HEAD
    static let descriptor = PIDDecodedValue(number: 0, kind: .fuelTrim)
=======
    static let descriptor = PIDDecodedValue(value: 0, kind: .fuelTrim)
>>>>>>> Inference
    func decodeValue(_ bytes: [UInt8]) -> Double? {
        guard let a = firstByte(bytes) else { return nil }
        return (Double(a) - 128.0) / 1.28
    }
}

struct FuelPressurePIDDecoder: NamedPIDDecoder {
<<<<<<< HEAD
    static let descriptor = PIDDecodedValue(number: 0, kind: .airPressure)
=======
    static let descriptor = PIDDecodedValue(value: 0, kind: .airPressure)
>>>>>>> Inference
    func decodeValue(_ bytes: [UInt8]) -> Double? {
        guard let a = firstByte(bytes) else { return nil }
        return Double(a) * 3.0
    }
}

struct FuelRailPressurePIDDecoder: NamedPIDDecoder {
<<<<<<< HEAD
    static let descriptor = PIDDecodedValue(number: 0, kind: .airPressure)
=======
    static let descriptor = PIDDecodedValue(value: 0, kind: .airPressure)
>>>>>>> Inference
    func decodeValue(_ bytes: [UInt8]) -> Double? {
        guard let value = word(bytes) else { return nil }
        return Double(value) * 0.079
    }
}

struct FuelRailGaugePressurePIDDecoder: NamedPIDDecoder {
<<<<<<< HEAD
    static let descriptor = PIDDecodedValue(number: 0, kind: .airPressure)
=======
    static let descriptor = PIDDecodedValue(value: 0, kind: .airPressure)
>>>>>>> Inference
    func decodeValue(_ bytes: [UInt8]) -> Double? {
        guard let value = word(bytes) else { return nil }
        return Double(value) * 10.0
    }
}

// MARK: - 16-bit Decoders

struct Percentage16PIDDecoder: NamedPIDDecoder {
<<<<<<< HEAD
    static let descriptor = PIDDecodedValue(number: 0, kind: .percentage)
=======
    static let descriptor = PIDDecodedValue(value: 0, kind: .percentage)
>>>>>>> Inference
    func decodeValue(_ bytes: [UInt8]) -> Double? {
        guard let value = word(bytes) else { return nil }
        return Double(value) * 100.0 / 65535.0
    }
}

struct Temperature16PIDDecoder: NamedPIDDecoder {
<<<<<<< HEAD
    static let descriptor = PIDDecodedValue(number: 0, kind: .temperature)
=======
    static let descriptor = PIDDecodedValue(value: 0, kind: .temperature)
>>>>>>> Inference
    func decodeValue(_ bytes: [UInt8]) -> Double? {
        guard let value = word(bytes) else { return nil }
        return Double(value) / 64.0 - 273.0
    }
}

// MARK: - Time/Distance Decoders

struct SecondsPIDDecoder: NamedPIDDecoder {
<<<<<<< HEAD
    static let descriptor = PIDDecodedValue(number: 0, kind: .duration)
=======
    static let descriptor = PIDDecodedValue(value: 0, kind: .duration)
>>>>>>> Inference
    func decodeValue(_ bytes: [UInt8]) -> Double? {
        guard let value = word(bytes) else { return nil }
        return Double(value)
    }
}

struct MinutesPIDDecoder: NamedPIDDecoder {
<<<<<<< HEAD
    static let descriptor = PIDDecodedValue(number: 0, kind: .duration)
=======
    static let descriptor = PIDDecodedValue(value: 0, kind: .duration)
>>>>>>> Inference
    func decodeValue(_ bytes: [UInt8]) -> Double? {
        guard let value = word(bytes) else { return nil }
        return Double(value)
    }
}

struct DistancePIDDecoder: NamedPIDDecoder {
<<<<<<< HEAD
    static let descriptor = PIDDecodedValue(number: 0, kind: .distance)
=======
    static let descriptor = PIDDecodedValue(value: 0, kind: .distance)
>>>>>>> Inference
    func decodeValue(_ bytes: [UInt8]) -> Double? {
        guard let value = word(bytes) else { return nil }
        return Double(value)
    }
}

// MARK: - Catalyst Temperature

struct CatalystTemperaturePIDDecoder: NamedPIDDecoder {
<<<<<<< HEAD
    static let descriptor = PIDDecodedValue(number: 0, kind: .temperature)
=======
    static let descriptor = PIDDecodedValue(value: 0, kind: .temperature)
>>>>>>> Inference
    func decodeValue(_ bytes: [UInt8]) -> Double? {
        guard let value = word(bytes) else { return nil }
        return Double(value) / 10.0 - 40.0
    }
}

// MARK: - Placeholder Decoders (SAE formula pending)

struct RatioPIDDecoder: NamedPIDDecoder {
<<<<<<< HEAD
    static let descriptor = PIDDecodedValue(number: 0, kind: .lambda)
=======
    static let descriptor = PIDDecodedValue(value: 0, kind: .lambda)
>>>>>>> Inference
    func decodeValue(_ bytes: [UInt8]) -> Double? {
        guard let value = word(bytes) else { return nil }
        return Double(value) * 2.0 / 65535.0
    }
}

struct OxygenSensorPIDDecoder: MultiValuePIDDecoder {
    static let primaryKind: PIDValueKind = .voltage

    func decode(_ bytes: [UInt8]) -> [PIDDecodedValue] {
        guard bytes.count >= 2 else { return [] }

        let voltage = Double(bytes[0]) / 200.0
        let trim = (Double(bytes[1]) - 128.0) / 1.28

        return [
<<<<<<< HEAD
            PIDDecodedValue(number: voltage, kind: .voltage, label: "Voltage"),
            PIDDecodedValue(number: trim, kind: .fuelTrim, label: "Short Fuel Trim")
=======
            PIDDecodedValue(value: voltage, kind: .voltage, label: "Voltage"),
            PIDDecodedValue(value: trim, kind: .fuelTrim, label: "Short Fuel Trim")
>>>>>>> Inference
        ]
    }
}

struct WidebandOxygenSensorPIDDecoder: MultiValuePIDDecoder {
    static let primaryKind: PIDValueKind = .lambda

    func decode(_ bytes: [UInt8]) -> [PIDDecodedValue] {
        guard let ratio = word(bytes), bytes.count >= 4 else { return [] }

        let lambda = Double(ratio) * 2.0 / 65535.0
        let secondaryWord = (UInt16(bytes[2]) << 8) | UInt16(bytes[3])
        let secondary = Double(Int16(bitPattern: secondaryWord)) / 256.0

        return [
<<<<<<< HEAD
            PIDDecodedValue(number: lambda, kind: .lambda, label: "Lambda"),
            PIDDecodedValue(number: secondary, kind: .current, label: "Pump Current")
=======
            PIDDecodedValue(value: lambda, kind: .lambda, label: "Lambda"),
            PIDDecodedValue(value: secondary, kind: .current, label: "Pump Current")
>>>>>>> Inference
        ]
    }
}

struct EngineTorquePIDDecoder: NamedPIDDecoder {
<<<<<<< HEAD
    static let descriptor = PIDDecodedValue(number: 0, kind: .torque)
=======
    static let descriptor = PIDDecodedValue(value: 0, kind: .torque)
>>>>>>> Inference
    func decodeValue(_ bytes: [UInt8]) -> Double? {
        guard let a = firstByte(bytes) else { return nil }
        return Double(Int(a) - 125)
    }
}

struct FrequencyPIDDecoder: NamedPIDDecoder {
<<<<<<< HEAD
    static let descriptor = PIDDecodedValue(number: 0, kind: .frequency)
=======
    static let descriptor = PIDDecodedValue(value: 0, kind: .frequency)
>>>>>>> Inference
    func decodeValue(_ bytes: [UInt8]) -> Double? {
        guard let value = word(bytes) else { return nil }
        return Double(value)
    }
}

struct ConcentrationPIDDecoder: NamedPIDDecoder {
<<<<<<< HEAD
    static let descriptor = PIDDecodedValue(number: 0, kind: .concentration)
=======
    static let descriptor = PIDDecodedValue(value: 0, kind: .concentration)
>>>>>>> Inference
    func decodeValue(_ bytes: [UInt8]) -> Double? {
        // TODO: Implement SAE formula for Concentration PID
        return nil
    }
}

struct EvapPressurePIDDecoder: NamedPIDDecoder {
<<<<<<< HEAD
    static let descriptor = PIDDecodedValue(number: 0, kind: .evapPressure)
=======
    static let descriptor = PIDDecodedValue(value: 0, kind: .evapPressure)
>>>>>>> Inference
    func decodeValue(_ bytes: [UInt8]) -> Double? {
        guard let value = signedWord(bytes) else { return nil }
        return Double(value) / 4.0
    }
}

struct FuelRatePIDDecoder: NamedPIDDecoder {
<<<<<<< HEAD
    static let descriptor = PIDDecodedValue(number: 0, kind: .fuelRate)
=======
    static let descriptor = PIDDecodedValue(value: 0, kind: .fuelRate)
>>>>>>> Inference
    func decodeValue(_ bytes: [UInt8]) -> Double? {
        guard let value = word(bytes) else { return nil }
        return Double(value) / 20.0
    }
}

struct InjectionTimingPIDDecoder: NamedPIDDecoder {
<<<<<<< HEAD
    static let descriptor = PIDDecodedValue(number: 0, kind: .angle)
=======
    static let descriptor = PIDDecodedValue(value: 0, kind: .angle)
>>>>>>> Inference
    func decodeValue(_ bytes: [UInt8]) -> Double? {
        guard let value = word(bytes) else { return nil }
        return Double(value) / 128.0 - 210.0
    }
}

struct CurrentPIDDecoder: NamedPIDDecoder {
<<<<<<< HEAD
    static let descriptor = PIDDecodedValue(number: 0, kind: .current)
=======
    static let descriptor = PIDDecodedValue(value: 0, kind: .current)
>>>>>>> Inference
    func decodeValue(_ bytes: [UInt8]) -> Double? {
        // TODO: Implement SAE formula for Current PID
        return nil
    }
}


// MARK: Unsupported

struct UnsupportedPIDDecoder: ProtocolPIDDecoding {
    static let shared = UnsupportedPIDDecoder()
<<<<<<< HEAD
    let descriptor = PIDDecodedValue(value: .bytes([]), kind: .raw)
=======
    let descriptor = PIDDecodedValue(value: 0, kind: .raw)
>>>>>>> Inference
    func decode(_ bytes: [UInt8]) -> [PIDDecodedValue] {
        []
    }
}

/*
 Roadmap:
 - Complete every SAE Mode 01 decoder.
 - Add multi-value decoder support.
 - Add status/bitfield decoding.
 - Add manufacturer decoder registry.
 - Add unit tests using official SAE examples.
 - Keep this file as the single source of truth for decoding logic.
*/
