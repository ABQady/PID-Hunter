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
        selectedProfile ?? currentProfile
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

            if let active = currentProfile,
               let refreshed = availableProfiles.first(where: { $0.id == active.id }) {
                currentProfile = refreshed
            }

            if let selected = selectedProfile,
               let refreshed = availableProfiles.first(where: { $0.id == selected.id }) {
                selectedProfile = refreshed
            }

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

        if !fingerprint.decodedCalibrationID.isEmpty {
            return fingerprint.decodedCalibrationID
        }

        return fingerprint.protocolName
    }

    // MARK: - Lifecycle

    @discardableResult
    func load(for fingerprint: BikeFingerprint) -> BikeProfile? {
        do {
            if let current = currentProfile,
               current.fingerprint != fingerprint {
                reset()
            }
            currentProfile = try store.load(for: fingerprint)

            if currentProfile == nil {
                Logger.shared.warning("⚠️ No Bike Profile exists for this ECU. Create one manually.")
            }

            selectedProfile = currentProfile
            reloadProfiles()
            if var profile = currentProfile,
               profile.displayName.isEmpty {
                profile.rename(to: defaultDisplayName(for: fingerprint))
                currentProfile = profile
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

    @discardableResult
    func createProfile(for fingerprint: BikeFingerprint, named name: String? = nil) -> BikeProfile? {
        var profile = BikeProfile(fingerprint: fingerprint)

        if let name {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                profile.rename(to: trimmed)
            }
        }

        do {
            try store.save(profile)
            currentProfile = profile
            selectedProfile = profile
            reloadProfiles()
            isDirty = false
            lastSaveDate = Date()
            Logger.shared.info("🆕 Created Bike Profile")
            return profile
        } catch {
            Logger.shared.error("❌ Failed to create Bike Profile: \(error.localizedDescription)")
            return nil
        }
    }

    func deleteProfile(_ profile: BikeProfile) {
        do {
            try store.delete(profile)

            if currentProfile?.id == profile.id {
                currentProfile = nil
            }

            if selectedProfile?.id == profile.id {
                selectedProfile = nil
            }

            reloadProfiles()
            Logger.shared.info("🗑 Deleted Bike Profile: \(profile.displayName)")
        } catch {
            Logger.shared.error("❌ Failed to delete Bike Profile: \(error.localizedDescription)")
        }
    }

    func createProfileFromCurrent(named name: String? = nil) {
        let fingerprint = ECUInfo.shared.fingerprint

        if currentProfile != nil {
            Logger.shared.info("Bike Profile already loaded.")
            return
        }

        _ = createProfile(for: fingerprint, named: name)
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
        guard var profile = selectedProfile ?? currentProfile else {
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
        try? store.save(profile)
        currentProfile = profile
        if let index = availableProfiles.firstIndex(where: { $0.id == profile.id }) {
            availableProfiles[index] = profile
        }
        if selectedProfile?.id == profile.id {
            selectedProfile = profile
        }
        isDirty = true
        autosaveIfNeeded()
    }

    func renameSelectedProfile(to newName: String) {
        rename(newName)
    }

    // MARK: - Knowledge

    func knowledge(
        mode: OBDMode,
        request: String
    ) -> DiscoveryRecord? {
        currentProfile?.discoveries.first {
            $0.header == ECUInfo.shared.header &&
            $0.mode == mode.rawValue &&
            $0.request == request
        }
    }

    func isKnown(
        mode: OBDMode,
        request: String
    ) -> Bool {
        currentProfile?.discoveries.contains {
            $0.header == ECUInfo.shared.header &&
            $0.mode == mode.rawValue &&
            $0.request == request
        } ?? false
    }

    private(set) var isDirty = false
    
    func record(
        mode: OBDMode,
        request: String,
        response: ELMResponse,
        latency: TimeInterval,
        source: RecordSource = .discovery,
        hadPartialResponse: Bool = false
    ) {
        guard var profile = currentProfile else { return }

        if let index = profile.discoveries.firstIndex(where: {
            $0.header == ECUInfo.shared.header &&
            $0.mode == mode.rawValue &&
            $0.request == request
        }) {
            profile.discoveries[index].record(
                response: response.raw,
                responseType: response.type,
                latency: latency
            )
            switch (profile.discoveries[index].source, source) {
            case (.confirmedNegative, .discovery):
                // Keep the stronger knowledge.
                break

            case (.retryPositive, .discovery):
                // Do not downgrade a retry-confirmed discovery.
                break

            default:
                profile.discoveries[index].source = source
            }
            profile.discoveries[index].hadPartialResponse =
                profile.discoveries[index].hadPartialResponse || hadPartialResponse
        } else {
            profile.discoveries.append(
                DiscoveryRecord(
                    header: ECUInfo.shared.header,
                    mode: mode.rawValue,
                    request: request,
                    response: response.raw,
                    firstSeen: .now,
                    lastSeen: .now,
                    hitCount: 1,
                    classification: DiscoveryClassification(from: response.type),
                    averageLatency: latency,
                    notes: [response.raw],
                    source: source,
                    hadPartialResponse: hadPartialResponse
                )
            )
        }

        profile.touch()
        currentProfile = profile
        if selectedProfile?.id == profile.id {
            selectedProfile = profile
        }
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
        if selectedProfile?.id == profile.id {
            selectedProfile = profile
        }

        do {
            try store.save(profile)
            Logger.shared.info("✅ Saved \(discoveries.count) header discoveries.")
        } catch {
            Logger.shared.error("❌ Failed to save header discoveries: \(error.localizedDescription)")
        }
    }
}
