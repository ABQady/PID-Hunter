//
//  ECUStatus.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 26/06/2026.
//
import Foundation

enum ECUStatus: String {

    case disconnected
    case scanningBLE
    case connected
    case initializingELM
    case settingProtocol
    case settingHeader
    case testingECU
    case mode01OK
    case mode21OK
    case mode22OK
    case noData
    case searching
    case busError
    case unableToConnect
    case timeout
    case unknown
    case connecting
    case checkingProtocol
    case waitingResponse
    case receivingResponse
    case idleScanning

}

extension ECUStatus {

    var title: String {
        switch self {
        case .disconnected:
            return "🔴 Disconnected"

        case .scanningBLE:
            return "🔍 Scanning BLE..."

        case .connecting:
            return "🔗 Connecting..."
        
        case .checkingProtocol:
            return "🔎 Checking Protocol..."
            
        case .connected:
            return "🟢 Connected"

        case .initializingELM:
            return "⚙️ Initializing ELM..."

        case .settingProtocol:
            return "📡 Setting Protocol..."
        
        case .waitingResponse:
            return "🕖 Waiting for response..."
            
        case .receivingResponse:
            return "⬆️ Recieving response..."
            
        case .idleScanning:
            return "🔎 Scanning..."

        case .settingHeader:
            return "📨 Setting Header..."

        case .testingECU:
            return "🧪 Testing ECU..."

        case .mode01OK:
            return "🎉 Mode 01 Working"

        case .mode21OK:
            return "🎉 Mode 21 Working"

        case .mode22OK:
            return "🎉 Mode 22 Working"

        case .noData:
            return "❌ NO DATA"

        case .searching:
            return "🔎 SEARCHING..."

        case .busError:
            return "🔥 BUS ERROR"

        case .unableToConnect:
            return "💀 UNABLE TO CONNECT"

        case .timeout:
            return "⏱️ TIMEOUT"

        case .unknown:
            return "❓ UNKNOWN"
        }
    }
}
