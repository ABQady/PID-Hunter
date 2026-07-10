//
//  BikeProfileManager.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 10/07/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class BikeProfileManager {

    static let shared = BikeProfileManager()

    private(set) var currentProfile: BikeProfile?

    private let store = BikeProfileStore.shared

    private var lastSaveDate = Date.distantPast
    private let autosaveInterval: TimeInterval = 20

    private init() {}

    // MARK: - Lifecycle

    @discardableResult
    func load(for fingerprint: BikeFingerprint) -> BikeProfile? {
        do {
            if let current = currentProfile,
               current.fingerprint != fingerprint {
                reset()
            }
            currentProfile = try store.loadOrCreate(for: fingerprint)
            if currentProfile?.displayName.isEmpty == true {
                currentProfile?.displayName = fingerprint.header
            }
            isDirty = false
            lastSaveDate = Date()

            Logger.shared.info("📂 Bike Profile Loaded")
            return currentProfile
        } catch {
            Logger.shared.error("❌ Failed to load Bike Profile: \(error.localizedDescription)")
            currentProfile = nil
            return nil
        }
    }

    private func autosaveIfNeeded() {
        let now = Date()

        guard now.timeIntervalSince(lastSaveDate) >= autosaveInterval else {
            return
        }

        save()
    }

    func save() {
        guard let currentProfile else { return }
        guard isDirty else { return }

        do {
            try store.save(currentProfile)
            isDirty = false
            lastSaveDate = Date()
        } catch {
            Logger.shared.error("❌ Failed to save Bike Profile: \(error.localizedDescription)")
        }
    }

    func rename(_ newName: String) {
        guard var profile = currentProfile else {
            return
        }

        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        guard trimmed != profile.displayName else {
            return
        }

        profile.displayName = trimmed
        currentProfile = profile
        isDirty = true
        autosaveIfNeeded()
    }

    // MARK: - Knowledge

    func knowledge(
        mode: OBDMode,
        request: String
    ) -> BikeKnowledge? {
        currentProfile?.discoveries[
            DiscoveryKey(mode: mode, request: request)
        ]
    }

    func isKnown(
        mode: OBDMode,
        request: String
    ) -> Bool {
        currentProfile?.discoveries[
            DiscoveryKey(mode: mode, request: request)
        ] != nil
    }

    private(set) var isDirty = false
    
    func record(
        mode: OBDMode,
        request: String,
        response: ELMResponse,
        classification: SearchResult
    ) {
        let key = DiscoveryKey(
            mode: mode,
            request: request
        )
        
        let state: DiscoveryState
        
        switch classification {
        case .positive:
            state = .discovered
        case .negative, .noData:
            state = .unsupported
        case .timeout:
            state = .timeout
        case .adapter:
            state = .adapter
        case .unknown:
            state = .unknown
        }

        guard var profile = currentProfile else { return }

        let now = Date()

        if var existing = profile.discoveries[key] {
            existing.lastSeen = now
            existing.hitCount += 1
            existing.response = response.raw
            existing.state = state
            profile.discoveries[key] = existing
        } else {
            profile.discoveries[key] = BikeKnowledge(
                response: response.raw,
                state: state,
                firstSeen: now,
                lastSeen: now,
                hitCount: 1
            )
        }

        currentProfile = profile
        isDirty = true
        autosaveIfNeeded()
    }

    var knownRequestCount: Int {
        currentProfile?.discoveries.count ?? 0
    }
    
    var profileDisplayName: String {
        currentProfile?.displayName ?? "No Bike Connected"
    }

    var coverage: Double {
        currentProfile?.coverage ?? 0
    }
    
    func unknownRequests(
        mode: OBDMode,
        from requests: [String]
    ) -> [String] {
        guard currentProfile != nil else {
            return requests
        }

        return requests.filter {
            !isKnown(mode: mode, request: $0)
        }
    }
    
    func buildQueue(
        for mode: OBDMode
    ) -> [String] {
        let queue = unknownRequests(
            mode: mode,
            from: mode.runtimeRequests
        )

        Logger.shared.info(
            "🧠 Bike Profile filtered \(mode.runtimeRequests.count - queue.count) known request(s)"
        )

        return queue
    }

    func flush() {
        save()
    }

    func reset() {
        save()
        isDirty = false
        lastSaveDate = .distantPast
        Logger.shared.info("🧹 Bike Profile Reset")
        currentProfile = nil
    }
}
