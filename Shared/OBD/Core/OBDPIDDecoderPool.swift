//
//  OBDPIDDecoderPool.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 18/07/2026.
//


/// Shared immutable decoder instances used by the standard PID database.
///
/// All PID decoders are stateless value types, so a single shared instance of
/// each decoder is reused across the application. This keeps the PID database
/// declarative while avoiding hundreds of identical decoder allocations.
enum OBDPIDDecoderPool {

    static let raw = RawPIDDecoder()
    static let percentage = PercentagePIDDecoder()
    static let temperature = TemperaturePIDDecoder()
    static let rpm = RPMPIDDecoder()
    static let speed = SpeedPIDDecoder()
    static let timingAdvance = TimingAdvancePIDDecoder()
    static let pressure = PressurePIDDecoder()
    static let voltage = VoltagePIDDecoder()
    static let maf = MAFPIDDecoder()

    static let fuelTrim = FuelTrimPIDDecoder()
    static let fuelPressure = FuelPressurePIDDecoder()
    static let fuelRailPressure = FuelRailPressurePIDDecoder()
    static let fuelRailGaugePressure = FuelRailGaugePressurePIDDecoder()

    static let percentage16 = Percentage16PIDDecoder()
    static let temperature16 = Temperature16PIDDecoder()

    static let seconds = SecondsPIDDecoder()
    static let minutes = MinutesPIDDecoder()
    static let distance = DistancePIDDecoder()
    static let ratio = RatioPIDDecoder()

    static let oxygenSensor = OxygenSensorPIDDecoder()
    static let widebandOxygenSensor = WidebandOxygenSensorPIDDecoder()

    static let catalystTemperature = CatalystTemperaturePIDDecoder()
    static let engineTorque = EngineTorquePIDDecoder()
    static let frequency = FrequencyPIDDecoder()
    static let concentration = ConcentrationPIDDecoder()
    static let evapPressure = EvapPressurePIDDecoder()
    static let fuelRate = FuelRatePIDDecoder()
    static let injectionTiming = InjectionTimingPIDDecoder()
    static let current = CurrentPIDDecoder()
}
