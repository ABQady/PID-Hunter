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

    init() {
        start()
    }
    
    func start() {
        refreshTask?.cancel()
        refreshTask = nil
        refreshTask = Task {
            for await snapshot in await Logger.shared.stream() {
                if Task.isCancelled { break }
                lines = snapshot
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func clear() {
        Task {
            Logger.shared.clear()
        }
    }

    func info(_ text: String) {
        Task {
            Logger.shared.info(text)
        }
    }

    func warning(_ text: String) {
        Task {
            Logger.shared.warning(text)
        }
    }

    func error(_ text: String) {
        Task {
            Logger.shared.error(text)
        }
    }

    func success(_ text: String) {
        Task {
            Logger.shared.success(text)
        }
    }

    func tx(_ text: String) {
        Task {
            Logger.shared.tx(text)
        }
    }

    func rx(_ text: String) {
        Task {
            Logger.shared.rx(text)
        }
    }
}
