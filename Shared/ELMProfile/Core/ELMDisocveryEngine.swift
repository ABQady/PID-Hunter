//
//  ELMDisocveryEngine.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 17/07/2026.
//

import Foundation

struct DiscoveryProgress: Sendable {
    let currentStep: Int
    let totalSteps: Int
    let title: String
}

actor ELMDiscoveryEngine {
    static let shared = ELMDiscoveryEngine()
    private let commands = ELMCommands.all.filter { $0.safetyLevel == .safe }
    private let clock = ContinuousClock()
    private let profileBuilder = ELMProfileBuilder()
    func discoverWithProgress(using elm: ELM327) -> AsyncStream<DiscoveryEvent> {
        AsyncStream { continuation in
            let task = Task {
                var results: [ELMCommandResult] = []
                let total = commands.count

                for (index, command) in commands.enumerated() {
                    if Task.isCancelled {
                        continuation.finish()
                        return
                    }

                    continuation.yield(.progress(.init(
                        currentStep: index + 1,
                        totalSteps: total,
                        title: command.command
                    )))

                    do {
                        try Task.checkCancellation()
                        let start = clock.now
                        let result = try await elm.send(command.command)
                        try Task.checkCancellation()

                        results.append(
                            ELMCommandResult(
                                command: command,
                                response: result.response.raw,
                                supported: command.matches(result.response.raw),
                                latency: result.latency
                            )
                        )
                    } catch {
                        if error is CancellationError {
                            continuation.finish()
                            return
                        }
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

                if Task.isCancelled {
                    continuation.finish()
                    return
                }

                let profile = profileBuilder.build(from: results)

                do {
                    try await ELMProfileStore.shared.save(profile)
                } catch {
                    print("Failed to save ELM profile: \(error)")
                }

                continuation.yield(.finished(profile))
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

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
        let profile = profileBuilder.build(from: results)

        do {
            try await ELMProfileStore.shared.save(profile)
        } catch {
            print("Failed to save ELM profile: \(error)")
        }

        return profile
    }

    func readFingerprint(using elm: ELM327) async throws -> ELMFingerprint {
        var results: [ELMCommandResult] = []

        for command in commands where command.isStandard {
            let result = try await elm.send(command.command)

            results.append(
                ELMCommandResult(
                    command: command,
                    response: result.response.raw,
                    supported: command.matches(result.response.raw),
                    latency: result.latency
                )
            )
        }

        let profile = profileBuilder.build(from: results)
        return profile.fingerprint
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
    enum DiscoveryEvent: Sendable {
        case progress(DiscoveryProgress)
        case finished(ELMProfile)
    }
}
