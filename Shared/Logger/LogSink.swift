//
//  LogSink.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 12/07/2026.
//

import Foundation

protocol LogSink {

    func startSession(fileURL: URL) throws

    func finish()

    func write(_ line: String)

    func flush()

}
