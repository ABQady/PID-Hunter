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

    private(set) var currentProfile: BikeProfile? {
        didSet {
            Logger.shared.warning(
                "BikeProfile: \(oldValue?.displayName ?? "nil") -> \(currentProfile?.displayName ?? "nil")"
            )
        }
    }

    private(set) var selectedProfile: BikeProfile?
    private(set) var availableProfiles: [BikeProfile] = []

    private let store = BikeProfileStore.shared

    private var lastSaveDate = Date.distantPast
    private let autosaveInterval: TimeInterval = 20

    private init() {}

    var displayedProfile: BikeProfile? {
        currentProfile ?? selectedProfile
    }

    var context: BikeProfileContext? {
        guard let profile = displayedProfile else {
            return nil
        }

        return BikeProfileContext(
            profile: profile,
            analytics: BikeAnalytics(profile: profile)
        )
    }

    func reloadProfiles() {
        do {
            availableProfiles = try store.loadAll()

            if selectedProfile == nil {
                selectedProfile = availableProfiles.first
            }
        } catch {
            Logger.shared.error("❌ Failed to load Bike Profiles: \(error.localizedDescription)")
            availableProfiles = []
        }
    }

    func selectProfile(_ profile: BikeProfile) {
        selectedProfile = profile
    }
    
    // Helper to generate a default display name based on fingerprint
    private func defaultDisplayName(for fingerprint: BikeFingerprint) -> String {
        if let vin = fingerprint.decodedVIN {
            return vin
        }

        if let calibration = fingerprint.decodedCalibrationID {
            return calibration
        }

        return fingerprint.header
    }

    // MARK: - Lifecycle

    @discardableResult
    func load(for fingerprint: BikeFingerprint) -> BikeProfile? {
        do {
            if let current = currentProfile,
               current.fingerprint != fingerprint {
                reset()
            }
            currentProfile = try store.loadOrCreate(for: fingerprint)
            selectedProfile = currentProfile
            reloadProfiles()
            if currentProfile?.displayName.isEmpty == true {
                currentProfile?.rename(to: defaultDisplayName(for: fingerprint))
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

        profile.rename(to: trimmed)
        currentProfile = profile
        selectedProfile = profile
        if let index = availableProfiles.firstIndex(where: { $0.fingerprint.id == profile.fingerprint.id }) {
            availableProfiles[index] = profile
        }
        isDirty = true
        autosaveIfNeeded()
    }

    // MARK: - Knowledge

    func knowledge(
        mode: OBDMode,
        request: String
    ) -> BikeKnowledge? {
        currentProfile?.discoveries[
            DiscoveryKey(
                header: currentProfile?.fingerprint.header ?? "",
                mode: mode,
                request: request
            )
        ]
    }

    func isKnown(
        mode: OBDMode,
        request: String
    ) -> Bool {
        currentProfile?.discoveries[
            DiscoveryKey(
                header: currentProfile?.fingerprint.header ?? "",
                mode: mode,
                request: request
            )
        ] != nil
    }

    private(set) var isDirty = false
    
    func record(
        mode: OBDMode,
        request: String,
        response: ELMResponse,
        latency: TimeInterval
    ) {
        guard var profile = currentProfile else { return }

        let key = DiscoveryKey(
            header: profile.fingerprint.header,
            mode: mode,
            request: request
        )

        if var existing = profile.discoveries[key] {
            existing.record(
                response: response.raw,
                responseType: response.type,
                latency: latency
            )
            profile.discoveries[key] = existing
        } else {
            profile.discoveries[key] = BikeKnowledge(
                firstSeen: .now,
                lastSeen: .now,
                hitCount: 1,
                lastResponse: response.raw,
                classification: DiscoveryClassification(from: response.type),
                averageLatency: latency
            )
        }

        profile.touch()
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

    func flush() {
        save()
    }

    func reset() {
        save()
        isDirty = false
        lastSaveDate = .distantPast
        Logger.shared.info("🧹 Bike Profile Reset")
        currentProfile = nil
        // Keep selectedProfile so the UI can continue browsing the last loaded bike while offline.
        reloadProfiles()
    }
    
    var headerDiscoveries: [HeaderDiscoveryResult] {
        currentProfile?.headerDiscoveries ?? []
    }
    
    func updateHeaderDiscoveries(_ discoveries: [HeaderDiscoveryResult]) {
        guard var profile = currentProfile else {
            Logger.shared.warning("No active Bike Profile to update.")
            return
        }

        if !discoveries.isEmpty {
            profile.headerDiscoveries = discoveries
        }
        currentProfile = profile
        selectedProfile = profile

        do {
            try store.save(profile)
            Logger.shared.info("✅ Saved \(discoveries.count) header discoveries.")
        } catch {
            Logger.shared.error("❌ Failed to save header discoveries: \(error.localizedDescription)")
        }
    }
}
