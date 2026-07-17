//
//  ELMDisocveryEngine.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 17/07/2026.
//

import Foundation

actor ELMDiscoveryEngine {
    static let shared = ELMDiscoveryEngine()
    private let commands = ELMCommands.all
    private let clock = ContinuousClock()
    private let profileBuilder = ELMProfileBuilder()

    func discover(using elm: ELM327) async -> ELMProfile {
        var results: [ELMCommandResult] = []
        for command in commands {
            let start = clock.now

            do {
                let result = try await elm.send(command.command)

                let latency = start.duration(to: clock.now)
                let supported = command.matches(result.response.raw)

                results.append(
                    ELMCommandResult(
                        command: command,
                        response: result.response.raw,
                        supported: supported,
                        latency: result.latency
                    )
                )
            } catch {
                results.append(
                    ELMCommandResult(
                        command: command,
                        response: "",
                        supported: false,
                        latency: nil
                    )
                )
            }
        }
        return profileBuilder.build(from: results)
    }

    var standardCommands: [ELMCommand] {
        commands.filter(\.isStandard)
    }

    var optionalCommands: [ELMCommand] {
        commands.filter(\.isOptional)
    }

    var vendorCommands: [ELMCommand] {
        commands.filter(\.isVendorSpecific)
    }
}
