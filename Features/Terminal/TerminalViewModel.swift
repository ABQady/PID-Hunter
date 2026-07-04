//
//  TerminalViewModel.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 04/07/2026.
//

import Foundation
import Observation

@Observable
@MainActor
final class TerminalViewModel {

    var lines: [LogLine] = []

    private var refreshTask: Task<Void, Never>?

    // Removed init to prevent automatic listening on construction.
    
    func start() {
        guard refreshTask == nil else { return }
        refreshTask = Task { @MainActor in
            for await snapshot in await Logger.shared.stream() {
                guard !Task.isCancelled else { break }
                withMutation(keyPath: \.lines) {
                    lines = snapshot
                }
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
        lines.removeAll(keepingCapacity: true)
    }

    func clear() {
        Logger.shared.clear()
    }

    func info(_ text: String) {
        Logger.shared.info(text)
    }

    func warning(_ text: String) {
        Logger.shared.warning(text)
    }

    func error(_ text: String) {
        Logger.shared.error(text)
    }

    func success(_ text: String) {
        Logger.shared.success(text)
    }

    func tx(_ text: String) {
        Logger.shared.tx(text)
    }

    func rx(_ text: String) {
        Logger.shared.rx(text)
    }
}
