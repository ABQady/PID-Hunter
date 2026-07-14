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

    private let lastSelectedProfileKey = "LastSelectedBikeProfileID"

    private var lastSelectedProfileID: String {
        get {
            UserDefaults.standard.string(forKey: lastSelectedProfileKey) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: lastSelectedProfileKey)
        }
    }

    private var lastSaveDate = Date.distantPast
    private let autosaveInterval: TimeInterval = 20

    private init() {}

    // During an active scan, currentProfile is the authoritative model.
    // selectedProfile is only used for browsing when there is no active profile.
    var displayedProfile: BikeProfile? {
        currentProfile ?? selectedProfile
    }

    var context: BikeProfileContext? {
        guard let profile = displayedProfile else {
            return nil
        }

        let analytics = BikeAnalytics(profile: profile)

        Logger.shared.info("""
        📊 Context
        Profile UUID : \(profile.id)
        Discoveries  : \(profile.discoveries.count)
        Total        : \(analytics.totalRequests)
        Coverage     : \(analytics.coverage)
        """)

        return BikeProfileContext(
            profile: profile,
            analytics: analytics
        )
    }

    func reloadProfiles() {
        do {
            availableProfiles = try store.loadAll()

            if let active = currentProfile,
               let refreshed = availableProfiles.first(where: { $0.id == active.id }) {
                currentProfile = refreshed
            }

            selectedProfile = availableProfiles.first {
                $0.id.uuidString == lastSelectedProfileID
            } ?? currentProfile ?? availableProfiles.first
        } catch {
            Logger.shared.error("❌ Failed to load Bike Profiles: \(error.localizedDescription)")
            availableProfiles = []
        }
    }

    func selectProfile(_ profile: BikeProfile) {
        selectedProfile = profile
        lastSelectedProfileID = profile.id.uuidString
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
            let profiles = try store.loadAll()
                .filter { $0.fingerprint.id == fingerprint.id }

            currentProfile = profiles.first {
                $0.id.uuidString == lastSelectedProfileID
            } ?? profiles.first

            if profiles.isEmpty {
                Logger.shared.warning("⚠️ No Bike Profile exists for this ECU. Create one manually.")
            }

            selectedProfile = currentProfile
            if let currentProfile {
                lastSelectedProfileID = currentProfile.id.uuidString
            }
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
            lastSelectedProfileID = profile.id.uuidString
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

        commitProfile(profile)
    }

    func renameSelectedProfile(to newName: String) {
        rename(newName)
    }

    // MARK: - Knowledge

    @inline(__always)
    private func discoveryIndex(
        in profile: BikeProfile,
        header: String,
        mode: OBDMode,
        request: String
    ) -> Int? {
        profile.discoveries.firstIndex {
            $0.header == header &&
            $0.mode == mode.rawValue &&
            $0.request == request
        }
    }

    @inline(__always)
    private func resolvedSource(
        current: RecordSource,
        incoming: RecordSource
    ) -> RecordSource {
        switch (current, incoming) {
        case (.confirmedNegative, .discovery):
            return current
        case (.retryPositive, .discovery):
            return current
        default:
            return incoming
        }
    }

    private(set) var isDirty = false
    
    private func commitProfile(_ profile: BikeProfile, markDirty: Bool = true) {
        currentProfile = profile

        if selectedProfile?.id == profile.id {
            selectedProfile = profile
        }

        if let index = availableProfiles.firstIndex(where: { $0.id == profile.id }) {
            availableProfiles[index] = profile
        }

        if markDirty {
            isDirty = true
            autosaveIfNeeded()
        }
    }
    
    func record(
        header: String,
        mode: OBDMode,
        request: String,
        response: ELMResponse,
        latency: TimeInterval,
        source: RecordSource = .discovery,
        hadPartialResponse: Bool = false
    ) {
        guard var profile = currentProfile else {
            Logger.shared.error("❌ record(): currentProfile is nil. Dropping discovery \(mode.rawValue) \(request) @ \(header)")
            return
        }

        let requestKey = "\(header) | \(mode.rawValue) | \(request)"

        Logger.shared.info("""
📝 Record Request
Request Key  : \(requestKey)
Response HDR : \(response.header ?? "-")
Response     : \(response.raw)
Source       : \(source)
Before Count : \(profile.discoveries.count)
""")

        Logger.shared.info("""
🔍 Persistence Decision
Request Header : \(header)
Response Header: \(response.header ?? "-")
Lookup Key     : \(requestKey)
""")

        if let index = discoveryIndex(
            in: profile,
            header: header,
            mode: mode,
            request: request
        ) {
            Logger.shared.info("♻️ Updating discovery: \(requestKey)")
            profile.discoveries[index].record(
                response: response.raw,
                responseType: response.type,
                latency: latency
            )
            Logger.shared.info("📄 Existing classification: \(profile.discoveries[index].classification)")
            profile.discoveries[index].source = resolvedSource(
                current: profile.discoveries[index].source,
                incoming: source
            )
            profile.discoveries[index].hadPartialResponse =
                profile.discoveries[index].hadPartialResponse || hadPartialResponse
        } else {
            Logger.shared.info("➕ Adding discovery: \(requestKey)")
            profile.discoveries.append(
                DiscoveryRecord(
                    header: header,
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
            if let added = profile.discoveries.last {
                Logger.shared.info("📄 Stored classification: \(added.classification)")
            }
            Logger.shared.info("📈 Discovery count after append: \(profile.discoveries.count)")
        }

        let discoveryCount = profile.discoveries.count
        profile.touch()
        Logger.shared.info("""
💾 Committing Bike Profile
Discoveries : \(discoveryCount)
Dirty        : true
""")
        commitProfile(profile)
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
        selectedProfile = nil
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
            profile.touch()
            lastSaveDate = .distantPast
            commitProfile(profile)
        }

        save()
        reloadProfiles()
        Logger.shared.info("✅ Saved \(discoveries.count) header discoveries.")
    }
}
