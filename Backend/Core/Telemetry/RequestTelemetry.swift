//
//  RequestTelemetry.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 03/07/2026.
//
import Foundation
import SwiftUI

struct RequestTelemetry: Identifiable {

    let id = UUID()

    let timestamp: Date

    let mode: OBDMode

    let pid: UInt16

    let header: String

    let latency: TimeInterval

    let response: ELMResponse

    let classification: SearchResult

    let retryCount: Int

    let searchEngine: SearchEngineType

}
