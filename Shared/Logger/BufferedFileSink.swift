//
//  BufferedFileSink.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 12/07/2026.
//

import Foundation

final class BufferedFileSink: LogSink {

    private let flushQueue = DispatchQueue(
        label: "PIDHunter.BufferedFileSink"
    )

    private let fileManager = FileManager.default
    private var handle: FileHandle?
    private(set) var currentFileURL: URL?
    private var buffer: [String] = []

    private let flushThreshold = 4 * 1024 // bytes
    private var bufferedBytes = 0
    private var flushTimer: DispatchSourceTimer?

    func startSession(fileURL: URL) throws {

        finish()

        self.currentFileURL = fileURL

        if !fileManager.fileExists(atPath: fileURL.path) {
            fileManager.createFile(atPath: fileURL.path, contents: nil)
        }

        handle = try FileHandle(forWritingTo: fileURL)
        try handle?.seekToEnd()

        flushTimer?.cancel()

        let timer = DispatchSource.makeTimerSource(queue: flushQueue)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in
            self?.flushLocked()
        }
        timer.resume()
        flushTimer = timer
    }

    func write(_ line: String) {

        flushQueue.async {
            guard self.handle != nil else { return }

            self.buffer.append(line)
            self.bufferedBytes += line.utf8.count + 1

            if self.bufferedBytes >= self.flushThreshold {
                self.flushLocked()
            }
        }
    }

    private func flushLocked() {

        guard
            let handle = self.handle,
            !self.buffer.isEmpty
        else {
            return
        }

        let payload = self.buffer.joined(separator: "\n") + "\n"

        if let data = payload.data(using: .utf8) {
            try? handle.write(contentsOf: data)
        }

        self.buffer.removeAll(keepingCapacity: true)
        self.bufferedBytes = 0
    }

    func flush() {
        flushQueue.sync {
            flushLocked()
        }
    }

    func finish() {

        let timer = flushTimer
        flushTimer = nil
        timer?.setEventHandler {}
        timer?.cancel()

        flush()

        try? handle?.close()
        handle = nil
        currentFileURL = nil

        buffer.removeAll(keepingCapacity: false)
        bufferedBytes = 0
    }
}
