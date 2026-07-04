//
//  ManualCommandSender.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 04/07/2026.
//

import Foundation

@MainActor
final class ManualCommandSender {

    static let shared = ManualCommandSender()

    private init() {}

    func send(
        bluetoothManager bt: BluetoothManager,
        manualCommand: inout String
    ) {
        guard bt.isConnected else {
            Task {
                Logger.shared.info("Connect to ELM first")}
            return
        }
        let normalizedCommand = manualCommand
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !normalizedCommand.isEmpty else {
            return
        }
        Task {
            Logger.shared.tx(normalizedCommand)}
        ELM327.shared.send(normalizedCommand)
        manualCommand.removeAll()
    }
}
