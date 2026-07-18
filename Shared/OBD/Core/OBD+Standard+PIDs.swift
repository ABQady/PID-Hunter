//
//  OBD+Standard+PIDs.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 18/07/2026.
//

import Foundation

/// SAE J1979 Standard Mode 01 PID definition.
struct StandardPID {
    let pid: UInt8
    let name: String
    let unit: String?
    let bytes: Int
    let description: String
    let decoder: any ProtocolPIDDecoding
    var category: PIDValueKind {
        decoder.descriptor.kind
    }
}

/// Canonical SAE J1979 Mode 01 PID registry.
///
/// This type intentionally contains metadata only.
/// All decoding logic lives in `ProtocolPIDDecoding`
/// implementations referenced by the PID definitions.
enum StandardPIDDatabase {
    /// This database is intended to become a complete SAE J1979 Mode 01 PID registry.
    /// PIDs are listed in numeric order for clarity and maintainability.
    private static let lookupTable = Dictionary(
        uniqueKeysWithValues: all.lazy.map { ($0.pid, $0) }
    )
    static let all: [StandardPID] = [
        // 0x03 Fuel System Status
        .init(pid: 0x03, name: "Fuel System Status", unit: nil, bytes: 2, description: "Current status of fuel system", decoder: OBDPIDDecoderPool.raw),
        // 0x04 Calculated Engine Load
        .init(pid: 0x04, name: "Calculated Engine Load", unit: "%", bytes: 1, description: "Calculated engine load", decoder: OBDPIDDecoderPool.percentage),
        // 0x05 Engine Coolant Temperature
        .init(pid: 0x05, name: "Engine Coolant Temperature", unit: "°C", bytes: 1, description: "Coolant temperature", decoder: OBDPIDDecoderPool.temperature),
        // 0x06 Short Term Fuel Trim Bank 1
        .init(pid: 0x06, name: "Short Term Fuel Trim Bank 1", unit: "%", bytes: 1, description: "STFT Bank 1", decoder: OBDPIDDecoderPool.fuelTrim),
        // 0x07 Long Term Fuel Trim Bank 1
        .init(pid: 0x07, name: "Long Term Fuel Trim Bank 1", unit: "%", bytes: 1, description: "LTFT Bank 1", decoder: OBDPIDDecoderPool.fuelTrim),
        // 0x08 Short Term Fuel Trim Bank 2
        .init(pid: 0x08, name: "Short Term Fuel Trim Bank 2", unit: "%", bytes: 1, description: "STFT Bank 2", decoder: OBDPIDDecoderPool.fuelTrim),
        // 0x09 Long Term Fuel Trim Bank 2
        .init(pid: 0x09, name: "Long Term Fuel Trim Bank 2", unit: "%", bytes: 1, description: "LTFT Bank 2", decoder: OBDPIDDecoderPool.fuelTrim),
        // 0x0A Fuel Pressure
        .init(pid: 0x0A, name: "Fuel Pressure", unit: "kPa", bytes: 1, description: "Fuel pressure", decoder: OBDPIDDecoderPool.fuelPressure),
        // 0x0B Intake Manifold Pressure
        .init(pid: 0x0B, name: "Intake Manifold Pressure", unit: "kPa", bytes: 1, description: "MAP", decoder: OBDPIDDecoderPool.pressure),
        // 0x0C Engine RPM
        .init(pid: 0x0C, name: "Engine RPM", unit: "rpm", bytes: 2, description: "Engine speed", decoder: OBDPIDDecoderPool.rpm),
        // 0x0D Vehicle Speed
        .init(pid: 0x0D, name: "Vehicle Speed", unit: "km/h", bytes: 1, description: "Vehicle speed", decoder: OBDPIDDecoderPool.speed),
        // 0x0E Ignition Timing Advance
        .init(pid: 0x0E, name: "Ignition Timing Advance", unit: "°", bytes: 1, description: "Timing advance", decoder: OBDPIDDecoderPool.timingAdvance),
        // 0x0F Intake Air Temperature
        .init(pid: 0x0F, name: "Intake Air Temperature", unit: "°C", bytes: 1, description: "IAT", decoder: OBDPIDDecoderPool.temperature),
        // 0x10 Mass Air Flow
        .init(pid: 0x10, name: "Mass Air Flow", unit: "g/s", bytes: 2, description: "MAF", decoder: OBDPIDDecoderPool.maf),
        // 0x11 Throttle Position
        .init(pid: 0x11, name: "Throttle Position", unit: "%", bytes: 1, description: "Throttle", decoder: OBDPIDDecoderPool.percentage),
        // 0x12 Commanded Secondary Air Status
        .init(pid: 0x12, name: "Commanded Secondary Air Status", unit: nil, bytes: 1, description: "Secondary air status", decoder: OBDPIDDecoderPool.raw),
        // 0x13 Oxygen Sensors Present (in 2 banks)
        .init(pid: 0x13, name: "Oxygen Sensors Present", unit: nil, bytes: 1, description: "O2 sensors present (bitmap)", decoder: OBDPIDDecoderPool.raw),
        // 0x14 Oxygen Sensor 1
        .init(pid: 0x14, name: "Oxygen Sensor 1", unit: "V", bytes: 2, description: "O2 Sensor 1 voltage/trim", decoder: OBDPIDDecoderPool.oxygenSensor),
        // 0x15 Oxygen Sensor 2
        .init(pid: 0x15, name: "Oxygen Sensor 2", unit: "V", bytes: 2, description: "O2 Sensor 2 voltage/trim", decoder: OBDPIDDecoderPool.oxygenSensor),
        // 0x16 Oxygen Sensor 3
        .init(pid: 0x16, name: "Oxygen Sensor 3", unit: "V", bytes: 2, description: "O2 Sensor 3 voltage/trim", decoder: OBDPIDDecoderPool.oxygenSensor),
        // 0x17 Oxygen Sensor 4
        .init(pid: 0x17, name: "Oxygen Sensor 4", unit: "V", bytes: 2, description: "O2 Sensor 4 voltage/trim", decoder: OBDPIDDecoderPool.oxygenSensor),
        // 0x18 Oxygen Sensor 5
        .init(pid: 0x18, name: "Oxygen Sensor 5", unit: "V", bytes: 2, description: "O2 Sensor 5 voltage/trim", decoder: OBDPIDDecoderPool.oxygenSensor),
        // 0x19 Oxygen Sensor 6
        .init(pid: 0x19, name: "Oxygen Sensor 6", unit: "V", bytes: 2, description: "O2 Sensor 6 voltage/trim", decoder: OBDPIDDecoderPool.oxygenSensor),
        // 0x1A Oxygen Sensor 7
        .init(pid: 0x1A, name: "Oxygen Sensor 7", unit: "V", bytes: 2, description: "O2 Sensor 7 voltage/trim", decoder: OBDPIDDecoderPool.oxygenSensor),
        // 0x1B Oxygen Sensor 8
        .init(pid: 0x1B, name: "Oxygen Sensor 8", unit: "V", bytes: 2, description: "O2 Sensor 8 voltage/trim", decoder: OBDPIDDecoderPool.oxygenSensor),
        // 0x1C OBD Standards Compliance
        .init(pid: 0x1C, name: "OBD Standards Compliance", unit: nil, bytes: 1, description: "OBD standards compliance", decoder: OBDPIDDecoderPool.raw),
        // 0x1D Oxygen Sensors Present (Alt)
        .init(pid: 0x1D, name: "Oxygen Sensors Present (Alt)", unit: nil, bytes: 1, description: "O2 sensors present (bitmap, alt)", decoder: OBDPIDDecoderPool.raw),
        // 0x1E Auxiliary Input Status
        .init(pid: 0x1E, name: "Auxiliary Input Status", unit: nil, bytes: 1, description: "Aux input status", decoder: OBDPIDDecoderPool.raw),
        // 0x1F Run Time Since Engine Start
        .init(pid: 0x1F, name: "Run Time Since Engine Start", unit: "s", bytes: 2, description: "Run time since engine start", decoder: OBDPIDDecoderPool.seconds),
        // 0x20 Supported PIDs 21-40
        .init(pid: 0x20, name: "Supported PIDs 21-40", unit: nil, bytes: 4, description: "Supported PIDs (bitmap)", decoder: OBDPIDDecoderPool.raw),
        // 0x21 Distance Traveled With MIL On
        .init(pid: 0x21, name: "Distance Traveled With MIL On", unit: "km", bytes: 2, description: "Distance with MIL on", decoder: OBDPIDDecoderPool.distance),
        // 0x22 Fuel Rail Pressure (relative to manifold vacuum)
        .init(pid: 0x22, name: "Fuel Rail Pressure", unit: "kPa", bytes: 2, description: "Fuel rail pressure (relative)", decoder: OBDPIDDecoderPool.fuelRailPressure),
        // 0x23 Fuel Rail Gauge Pressure
        .init(pid: 0x23, name: "Fuel Rail Gauge Pressure", unit: "kPa", bytes: 2, description: "Fuel rail gauge pressure", decoder: OBDPIDDecoderPool.fuelRailGaugePressure),
        // 0x24 Wide Range O2 Sensor 1 (Equivalence Ratio/Voltage)
        .init(pid: 0x24, name: "Wide Range O2 Sensor 1", unit: nil, bytes: 4, description: "Wide range O2 sensor 1", decoder: OBDPIDDecoderPool.widebandOxygenSensor),
        .init(pid: 0x25, name: "Wide Range O2 Sensor 2", unit: nil, bytes: 4, description: "Wide range O2 sensor 2", decoder: OBDPIDDecoderPool.widebandOxygenSensor),
        .init(pid: 0x26, name: "Wide Range O2 Sensor 3", unit: nil, bytes: 4, description: "Wide range O2 sensor 3", decoder: OBDPIDDecoderPool.widebandOxygenSensor),
        .init(pid: 0x27, name: "Wide Range O2 Sensor 4", unit: nil, bytes: 4, description: "Wide range O2 sensor 4", decoder: OBDPIDDecoderPool.widebandOxygenSensor),
        .init(pid: 0x28, name: "Wide Range O2 Sensor 5", unit: nil, bytes: 4, description: "Wide range O2 sensor 5", decoder: OBDPIDDecoderPool.widebandOxygenSensor),
        .init(pid: 0x29, name: "Wide Range O2 Sensor 6", unit: nil, bytes: 4, description: "Wide range O2 sensor 6", decoder: OBDPIDDecoderPool.widebandOxygenSensor),
        .init(pid: 0x2A, name: "Wide Range O2 Sensor 7", unit: nil, bytes: 4, description: "Wide range O2 sensor 7", decoder: OBDPIDDecoderPool.widebandOxygenSensor),
        .init(pid: 0x2B, name: "Wide Range O2 Sensor 8", unit: nil, bytes: 4, description: "Wide range O2 sensor 8", decoder: OBDPIDDecoderPool.widebandOxygenSensor),
        // 0x2C Commanded EGR
        .init(pid: 0x2C, name: "Commanded EGR", unit: "%", bytes: 1, description: "Commanded EGR", decoder: OBDPIDDecoderPool.percentage),
        // 0x2D EGR Error
        .init(pid: 0x2D, name: "EGR Error", unit: "%", bytes: 1, description: "EGR error", decoder: OBDPIDDecoderPool.percentage),
        // 0x2E Commanded Evaporative Purge
        .init(pid: 0x2E, name: "Commanded Evaporative Purge", unit: "%", bytes: 1, description: "Commanded evap purge", decoder: OBDPIDDecoderPool.percentage),
        // 0x2F Fuel Level Input
        .init(pid: 0x2F, name: "Fuel Level", unit: "%", bytes: 1, description: "Fuel level", decoder: OBDPIDDecoderPool.percentage),
        // 0x30 Number of Warm-ups Since Codes Cleared
        .init(pid: 0x30, name: "Warm-ups Since DTC Cleared", unit: nil, bytes: 1, description: "Warm-ups since DTC cleared", decoder: OBDPIDDecoderPool.raw),
        // 0x31 Distance Since DTC Cleared
        .init(pid: 0x31, name: "Distance Since DTC Cleared", unit: "km", bytes: 2, description: "Distance since DTC cleared", decoder: OBDPIDDecoderPool.distance),
        // 0x32 Evap System Vapor Pressure
        .init(pid: 0x32, name: "Evap System Vapor Pressure", unit: "Pa", bytes: 2, description: "Evap system vapor pressure", decoder: OBDPIDDecoderPool.evapPressure),
        // 0x33 Absolute Barometric Pressure
        .init(pid: 0x33, name: "Absolute Barometric Pressure", unit: "kPa", bytes: 1, description: "Barometric pressure", decoder: OBDPIDDecoderPool.pressure),
        // 0x34-0x3B Wide Range O2 Sensor Current (not all vehicles support)
        .init(pid: 0x34, name: "Wide Range O2 Sensor 1 Current", unit: "mA", bytes: 4, description: "Wide range O2 sensor 1 current", decoder: OBDPIDDecoderPool.widebandOxygenSensor),
        .init(pid: 0x35, name: "Wide Range O2 Sensor 2 Current", unit: "mA", bytes: 4, description: "Wide range O2 sensor 2 current", decoder: OBDPIDDecoderPool.widebandOxygenSensor),
        .init(pid: 0x36, name: "Wide Range O2 Sensor 3 Current", unit: "mA", bytes: 4, description: "Wide range O2 sensor 3 current", decoder: OBDPIDDecoderPool.widebandOxygenSensor),
        .init(pid: 0x37, name: "Wide Range O2 Sensor 4 Current", unit: "mA", bytes: 4, description: "Wide range O2 sensor 4 current", decoder: OBDPIDDecoderPool.widebandOxygenSensor),
        .init(pid: 0x38, name: "Wide Range O2 Sensor 5 Current", unit: "mA", bytes: 4, description: "Wide range O2 sensor 5 current", decoder: OBDPIDDecoderPool.widebandOxygenSensor),
        .init(pid: 0x39, name: "Wide Range O2 Sensor 6 Current", unit: "mA", bytes: 4, description: "Wide range O2 sensor 6 current", decoder: OBDPIDDecoderPool.widebandOxygenSensor),
        .init(pid: 0x3A, name: "Wide Range O2 Sensor 7 Current", unit: "mA", bytes: 4, description: "Wide range O2 sensor 7 current", decoder: OBDPIDDecoderPool.widebandOxygenSensor),
        .init(pid: 0x3B, name: "Wide Range O2 Sensor 8 Current", unit: "mA", bytes: 4, description: "Wide range O2 sensor 8 current", decoder: OBDPIDDecoderPool.widebandOxygenSensor),
        // 0x3C Catalyst Temperature Bank1 Sensor1
        .init(pid: 0x3C, name: "Catalyst Temperature Bank1 Sensor1", unit: "°C", bytes: 2, description: "Catalyst temp B1S1", decoder: OBDPIDDecoderPool.temperature16),
        // 0x3D Catalyst Temperature Bank2 Sensor1
        .init(pid: 0x3D, name: "Catalyst Temperature Bank2 Sensor1", unit: "°C", bytes: 2, description: "Catalyst temp B2S1", decoder: OBDPIDDecoderPool.temperature16),
        // 0x3E Catalyst Temperature Bank1 Sensor2
        .init(pid: 0x3E, name: "Catalyst Temperature Bank1 Sensor2", unit: "°C", bytes: 2, description: "Catalyst temp B1S2", decoder: OBDPIDDecoderPool.temperature16),
        // 0x3F Catalyst Temperature Bank2 Sensor2
        .init(pid: 0x3F, name: "Catalyst Temperature Bank2 Sensor2", unit: "°C", bytes: 2, description: "Catalyst temp B2S2", decoder: OBDPIDDecoderPool.temperature16),
        // 0x40 Supported PIDs 41-60
        .init(pid: 0x40, name: "Supported PIDs 41-60", unit: nil, bytes: 4, description: "Supported PIDs (bitmap)", decoder: OBDPIDDecoderPool.raw),
        // 0x41 Monitor Status This Drive Cycle
        .init(pid: 0x41, name: "Monitor Status This Drive Cycle", unit: nil, bytes: 4, description: "Monitor status this drive cycle", decoder: OBDPIDDecoderPool.raw),
        // 0x42 Control Module Voltage
        .init(pid: 0x42, name: "Control Module Voltage", unit: "V", bytes: 2, description: "ECU voltage", decoder: OBDPIDDecoderPool.voltage),
        // 0x43 Absolute Load Value
        .init(pid: 0x43, name: "Absolute Load Value", unit: "%", bytes: 2, description: "Absolute load value", decoder: OBDPIDDecoderPool.percentage16),
        // 0x44 Commanded Equivalence Ratio
        .init(pid: 0x44, name: "Commanded Equivalence Ratio", unit: nil, bytes: 2, description: "Commanded equivalence ratio", decoder: OBDPIDDecoderPool.ratio),
        // 0x45 Relative Throttle Position
        .init(pid: 0x45, name: "Relative Throttle Position", unit: "%", bytes: 1, description: "Relative throttle position", decoder: OBDPIDDecoderPool.percentage),
        // 0x46 Ambient Air Temperature
        .init(pid: 0x46, name: "Ambient Air Temperature", unit: "°C", bytes: 1, description: "Ambient temperature", decoder: OBDPIDDecoderPool.temperature),
        // 0x47 Absolute Throttle Position B
        .init(pid: 0x47, name: "Absolute Throttle Position B", unit: "%", bytes: 1, description: "Absolute throttle B", decoder: OBDPIDDecoderPool.percentage),
        // 0x48 Absolute Throttle Position C
        .init(pid: 0x48, name: "Absolute Throttle Position C", unit: "%", bytes: 1, description: "Absolute throttle C", decoder: OBDPIDDecoderPool.percentage),
        // 0x49 Accelerator Pedal Position D
        .init(pid: 0x49, name: "Accelerator Pedal Position D", unit: "%", bytes: 1, description: "Accelerator pedal D", decoder: OBDPIDDecoderPool.percentage),
        // 0x4A Accelerator Pedal Position E
        .init(pid: 0x4A, name: "Accelerator Pedal Position E", unit: "%", bytes: 1, description: "Accelerator pedal E", decoder: OBDPIDDecoderPool.percentage),
        // 0x4B Accelerator Pedal Position F
        .init(pid: 0x4B, name: "Accelerator Pedal Position F", unit: "%", bytes: 1, description: "Accelerator pedal F", decoder: OBDPIDDecoderPool.percentage),
        // 0x4C Commanded Throttle Actuator
        .init(pid: 0x4C, name: "Commanded Throttle Actuator", unit: "%", bytes: 1, description: "Commanded throttle actuator", decoder: OBDPIDDecoderPool.percentage),
        // 0x4D Time Run With MIL On
        .init(pid: 0x4D, name: "Time Run With MIL On", unit: "min", bytes: 2, description: "Time run with MIL on", decoder: OBDPIDDecoderPool.minutes),
        // 0x4E Time Since Trouble Codes Cleared
        .init(pid: 0x4E, name: "Time Since Trouble Codes Cleared", unit: "min", bytes: 2, description: "Time since DTC cleared", decoder: OBDPIDDecoderPool.minutes),
        // 0x4F Maximum Values (air flow, etc.)
        .init(pid: 0x4F, name: "Maximum Values", unit: nil, bytes: 4, description: "Maximum values (air flow, etc.)", decoder: OBDPIDDecoderPool.raw),
        // 0x50 Maximum Air Flow Rate
        .init(pid: 0x50, name: "Maximum Air Flow Rate", unit: "g/s", bytes: 2, description: "Maximum air flow rate", decoder: OBDPIDDecoderPool.maf),
        // 0x51 Fuel Type
        .init(pid: 0x51, name: "Fuel Type", unit: nil, bytes: 1, description: "Fuel type", decoder: OBDPIDDecoderPool.raw),
        // 0x52 Ethanol Fuel Percentage
        .init(pid: 0x52, name: "Ethanol Fuel Percentage", unit: "%", bytes: 1, description: "Ethanol fuel %", decoder: OBDPIDDecoderPool.percentage),
        // 0x53 Absolute Evap System Vapor Pressure
        .init(pid: 0x53, name: "Absolute Evap System Vapor Pressure", unit: "kPa", bytes: 2, description: "Absolute evap vapor pressure", decoder: OBDPIDDecoderPool.pressure),
        // 0x54 Evap System Vapor Pressure
        .init(pid: 0x54, name: "Evap System Vapor Pressure", unit: "Pa", bytes: 2, description: "Evap system vapor pressure", decoder: OBDPIDDecoderPool.evapPressure),
        // 0x55 Short Term Secondary O2 Sensor Trim Bank1
        .init(pid: 0x55, name: "Short Term Secondary O2 Sensor Trim Bank1", unit: "%", bytes: 1, description: "Short term secondary O2 trim B1", decoder: OBDPIDDecoderPool.fuelTrim),
        // 0x56 Long Term Secondary O2 Sensor Trim Bank1
        .init(pid: 0x56, name: "Long Term Secondary O2 Sensor Trim Bank1", unit: "%", bytes: 1, description: "Long term secondary O2 trim B1", decoder: OBDPIDDecoderPool.fuelTrim),
        // 0x57 Short Term Secondary O2 Sensor Trim Bank2
        .init(pid: 0x57, name: "Short Term Secondary O2 Sensor Trim Bank2", unit: "%", bytes: 1, description: "Short term secondary O2 trim B2", decoder: OBDPIDDecoderPool.fuelTrim),
        // 0x58 Long Term Secondary O2 Sensor Trim Bank2
        .init(pid: 0x58, name: "Long Term Secondary O2 Sensor Trim Bank2", unit: "%", bytes: 1, description: "Long term secondary O2 trim B2", decoder: OBDPIDDecoderPool.fuelTrim),
        // 0x59 Fuel Rail Absolute Pressure
        .init(pid: 0x59, name: "Fuel Rail Absolute Pressure", unit: "kPa", bytes: 2, description: "Fuel rail absolute pressure", decoder: OBDPIDDecoderPool.fuelRailPressure),
        // 0x5A Relative Accelerator Pedal Position
        .init(pid: 0x5A, name: "Relative Accelerator Pedal Position", unit: "%", bytes: 1, description: "Relative accelerator pedal position", decoder: OBDPIDDecoderPool.percentage),
        // 0x5B Hybrid Battery Pack Remaining Life
        .init(pid: 0x5B, name: "Hybrid Battery Pack Remaining Life", unit: "%", bytes: 1, description: "Hybrid battery life %", decoder: OBDPIDDecoderPool.percentage),
        // 0x5C Engine Oil Temperature
        .init(pid: 0x5C, name: "Engine Oil Temperature", unit: "°C", bytes: 1, description: "Engine oil temperature", decoder: OBDPIDDecoderPool.temperature),
        // 0x5D Fuel Injection Timing
        .init(pid: 0x5D, name: "Fuel Injection Timing", unit: "°", bytes: 2, description: "Fuel injection timing", decoder: OBDPIDDecoderPool.injectionTiming),
        // 0x5E Engine Fuel Rate
        .init(pid: 0x5E, name: "Engine Fuel Rate", unit: "L/h", bytes: 2, description: "Engine fuel rate", decoder: OBDPIDDecoderPool.fuelRate),
        // 0x5F Emission Requirements
        .init(pid: 0x5F, name: "Emission Requirements", unit: nil, bytes: 1, description: "Emission requirements", decoder: OBDPIDDecoderPool.raw),
        // 0x60 Supported PIDs 61-80
        .init(pid: 0x60, name: "Supported PIDs 61-80", unit: nil, bytes: 4, description: "Supported PIDs (bitmap 61-80)", decoder: OBDPIDDecoderPool.raw),
        // 0x61 Driver's Demand Engine - Percent Torque
        .init(pid: 0x61, name: "Driver's Demand Engine - Percent Torque", unit: "%", bytes: 1, description: "Driver's demand engine percent torque", decoder: OBDPIDDecoderPool.percentage),
        // 0x62 Actual Engine - Percent Torque
        .init(pid: 0x62, name: "Actual Engine - Percent Torque", unit: "%", bytes: 1, description: "Actual engine percent torque", decoder: OBDPIDDecoderPool.percentage),
        // 0x63 Engine Reference Torque
        .init(pid: 0x63, name: "Engine Reference Torque", unit: "Nm", bytes: 2, description: "Reference engine torque", decoder: OBDPIDDecoderPool.engineTorque),
        // 0x64 Engine Percent Torque Data
        .init(pid: 0x64, name: "Engine Percent Torque Data", unit: "%", bytes: 5, description: "Engine percent torque data (bitmap)", decoder: OBDPIDDecoderPool.raw),
        // 0x65 Auxiliary Input/Output Supported
        .init(pid: 0x65, name: "Auxiliary Input/Output Supported", unit: nil, bytes: 2, description: "Auxiliary I/O supported", decoder: OBDPIDDecoderPool.raw),
        // 0x66 Mass Air Flow Sensor (A) - Frequency
        .init(pid: 0x66, name: "Mass Air Flow Sensor (A) - Frequency", unit: "Hz", bytes: 2, description: "MAF sensor A frequency", decoder: OBDPIDDecoderPool.frequency),
        // 0x67 Mass Air Flow Sensor (B) - Frequency
        .init(pid: 0x67, name: "Mass Air Flow Sensor (B) - Frequency", unit: "Hz", bytes: 2, description: "MAF sensor B frequency", decoder: OBDPIDDecoderPool.frequency),
        // 0x68 Intake Manifold Absolute Pressure Sensor (A)
        .init(pid: 0x68, name: "Intake Manifold Absolute Pressure Sensor (A)", unit: "kPa", bytes: 2, description: "MAP sensor A", decoder: OBDPIDDecoderPool.pressure),
        // 0x69 Intake Manifold Absolute Pressure Sensor (B)
        .init(pid: 0x69, name: "Intake Manifold Absolute Pressure Sensor (B)", unit: "kPa", bytes: 2, description: "MAP sensor B", decoder: OBDPIDDecoderPool.pressure),
        // 0x6A Exhaust Gas Temperature Bank 1 Sensor 1
        .init(pid: 0x6A, name: "Exhaust Gas Temperature Bank 1 Sensor 1", unit: "°C", bytes: 2, description: "EGT B1S1", decoder: OBDPIDDecoderPool.temperature16),
        // 0x6B Exhaust Gas Temperature Bank 1 Sensor 2
        .init(pid: 0x6B, name: "Exhaust Gas Temperature Bank 1 Sensor 2", unit: "°C", bytes: 2, description: "EGT B1S2", decoder: OBDPIDDecoderPool.temperature16),
        // 0x6C Exhaust Gas Temperature Bank 2 Sensor 1
        .init(pid: 0x6C, name: "Exhaust Gas Temperature Bank 2 Sensor 1", unit: "°C", bytes: 2, description: "EGT B2S1", decoder: OBDPIDDecoderPool.temperature16),
        // 0x6D Exhaust Gas Temperature Bank 2 Sensor 2
        .init(pid: 0x6D, name: "Exhaust Gas Temperature Bank 2 Sensor 2", unit: "°C", bytes: 2, description: "EGT B2S2", decoder: OBDPIDDecoderPool.temperature16),
        // 0x6E Diesel Particulate Filter Differential Pressure
        .init(pid: 0x6E, name: "Diesel Particulate Filter Differential Pressure", unit: "kPa", bytes: 2, description: "DPF differential pressure", decoder: OBDPIDDecoderPool.pressure),
        // 0x6F Exhaust Gas Recirculation Temperature
        .init(pid: 0x6F, name: "Exhaust Gas Recirculation Temperature", unit: "°C", bytes: 2, description: "EGR temperature", decoder: OBDPIDDecoderPool.temperature16),
        // 0x70 NOx NTE Control Area Status
        .init(pid: 0x70, name: "NOx NTE Control Area Status", unit: nil, bytes: 1, description: "NOx NTE control area status", decoder: OBDPIDDecoderPool.raw),
        // 0x71 PM NTE Control Area Status
        .init(pid: 0x71, name: "PM NTE Control Area Status", unit: nil, bytes: 1, description: "PM NTE control area status", decoder: OBDPIDDecoderPool.raw),
        // 0x72 Engine Run Time for Auxiliary Emissions Control Device
        .init(pid: 0x72, name: "Engine Run Time for Aux Emissions Control Device", unit: "s", bytes: 2, description: "Engine run time for auxiliary emissions control device", decoder: OBDPIDDecoderPool.seconds),
        // 0x73 Engine Run Time for Purg Control
        .init(pid: 0x73, name: "Engine Run Time for Purge Control", unit: "s", bytes: 2, description: "Engine run time for purge control", decoder: OBDPIDDecoderPool.seconds),
        // 0x74 NOx Sensor (1)
        .init(pid: 0x74, name: "NOx Sensor 1", unit: "ppm", bytes: 2, description: "NOx sensor 1", decoder: OBDPIDDecoderPool.concentration),
        // 0x75 NOx Sensor (2)
        .init(pid: 0x75, name: "NOx Sensor 2", unit: "ppm", bytes: 2, description: "NOx sensor 2", decoder: OBDPIDDecoderPool.concentration),
        // 0x76 PM Sensor (1)
        .init(pid: 0x76, name: "PM Sensor 1", unit: "mg/m3", bytes: 2, description: "Particulate matter sensor 1", decoder: OBDPIDDecoderPool.concentration),
        // 0x77 PM Sensor (2)
        .init(pid: 0x77, name: "PM Sensor 2", unit: "mg/m3", bytes: 2, description: "Particulate matter sensor 2", decoder: OBDPIDDecoderPool.concentration),
        // 0x78 Intake Manifold Temperature
        .init(pid: 0x78, name: "Intake Manifold Temperature", unit: "°C", bytes: 2, description: "Intake manifold temperature", decoder: OBDPIDDecoderPool.temperature16),
        // 0x79 Turbocharger Compressor Inlet Pressure
        .init(pid: 0x79, name: "Turbocharger Compressor Inlet Pressure", unit: "kPa", bytes: 2, description: "Turbocharger compressor inlet pressure", decoder: OBDPIDDecoderPool.pressure),
        // 0x7A Boost Pressure Control
        .init(pid: 0x7A, name: "Boost Pressure Control", unit: "kPa", bytes: 2, description: "Boost pressure control", decoder: OBDPIDDecoderPool.pressure),
        // 0x7B Variable Geometry Turbo (VGT) Control
        .init(pid: 0x7B, name: "Variable Geometry Turbo Control", unit: "%", bytes: 1, description: "VGT control", decoder: OBDPIDDecoderPool.percentage),
        // 0x7C Wastegate Control
        .init(pid: 0x7C, name: "Wastegate Control", unit: "%", bytes: 1, description: "Wastegate control", decoder: OBDPIDDecoderPool.percentage),
        // 0x7D Exhaust Pressure
        .init(pid: 0x7D, name: "Exhaust Pressure", unit: "kPa", bytes: 2, description: "Exhaust pressure", decoder: OBDPIDDecoderPool.pressure),
        // 0x7E Turbocharger RPM
        .init(pid: 0x7E, name: "Turbocharger RPM", unit: "rpm", bytes: 2, description: "Turbocharger RPM", decoder: OBDPIDDecoderPool.rpm),
        // 0x7F Turbocharger Temperature
        .init(pid: 0x7F, name: "Turbocharger Temperature", unit: "°C", bytes: 2, description: "Turbocharger temperature", decoder: OBDPIDDecoderPool.temperature16),
        // 0x80 Supported PIDs 81-A0
        .init(pid: 0x80, name: "Supported PIDs 81-A0", unit: nil, bytes: 4, description: "Supported PIDs (bitmap 81-A0)", decoder: OBDPIDDecoderPool.raw),
        // 0x81 NOx Sensor 3
        .init(pid: 0x81, name: "NOx Sensor 3", unit: "ppm", bytes: 2, description: "NOx sensor 3", decoder: OBDPIDDecoderPool.concentration),
        // 0x82 NOx Sensor 4
        .init(pid: 0x82, name: "NOx Sensor 4", unit: "ppm", bytes: 2, description: "NOx sensor 4", decoder: OBDPIDDecoderPool.concentration),
        // 0x83 PM Sensor 3
        .init(pid: 0x83, name: "PM Sensor 3", unit: "mg/m3", bytes: 2, description: "Particulate matter sensor 3", decoder: OBDPIDDecoderPool.concentration),
        // 0x84 PM Sensor 4
        .init(pid: 0x84, name: "PM Sensor 4", unit: "mg/m3", bytes: 2, description: "Particulate matter sensor 4", decoder: OBDPIDDecoderPool.concentration),
        // 0x85 Intake Manifold Temperature (B)
        .init(pid: 0x85, name: "Intake Manifold Temperature (B)", unit: "°C", bytes: 2, description: "Intake manifold temperature (B)", decoder: OBDPIDDecoderPool.temperature16),
        // 0x86-0x9F Reserved/Manufacturer-defined
        // 0xA0 Supported PIDs A1-C0
        .init(pid: 0xA0, name: "Supported PIDs A1-C0", unit: nil, bytes: 4, description: "Supported PIDs (bitmap A1-C0)", decoder: OBDPIDDecoderPool.raw),
        // 0xA1 NOx Sensor 5
        .init(pid: 0xA1, name: "NOx Sensor 5", unit: "ppm", bytes: 2, description: "NOx sensor 5", decoder: OBDPIDDecoderPool.concentration),
        // 0xA2 NOx Sensor 6
        .init(pid: 0xA2, name: "NOx Sensor 6", unit: "ppm", bytes: 2, description: "NOx sensor 6", decoder: OBDPIDDecoderPool.concentration),
        // 0xA3 PM Sensor 5
        .init(pid: 0xA3, name: "PM Sensor 5", unit: "mg/m3", bytes: 2, description: "Particulate matter sensor 5", decoder: OBDPIDDecoderPool.concentration),
        // 0xA4 PM Sensor 6
        .init(pid: 0xA4, name: "PM Sensor 6", unit: "mg/m3", bytes: 2, description: "Particulate matter sensor 6", decoder: OBDPIDDecoderPool.concentration),
        // 0xA5 Intake Manifold Temperature (C)
        .init(pid: 0xA5, name: "Intake Manifold Temperature (C)", unit: "°C", bytes: 2, description: "Intake manifold temperature (C)", decoder: OBDPIDDecoderPool.temperature16),
        // 0xA6-0xBF Reserved/Manufacturer-defined
        // 0xC0 Supported PIDs C1-E0
        .init(pid: 0xC0, name: "Supported PIDs C1-E0", unit: nil, bytes: 4, description: "Supported PIDs (bitmap C1-E0)", decoder: OBDPIDDecoderPool.raw)
    ]

    static func lookup(_ pid: UInt8) -> StandardPID? {
        lookupTable[pid]
    }
}

// MARK: - Future work
/*
 TODO:
 - Expand to every SAE J1979 Mode 01 PID.
 - Add decoding formulas.
 - Add expected byte layout.
 - Add value ranges.
 - Add categories (Engine, Fuel, Emissions, Electrical...).
 - Add aliases for display/search.
 */
