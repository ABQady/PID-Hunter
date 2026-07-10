//
//  ScanPersistence.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 09/07/2026.
//
import Foundation
import Combine

@MainActor
final class ScanPersistence {

    static let shared = ScanPersistence()
    @Published private(set) var hasResumePoint = false

    private init() {
        refreshResumeAvailability()
    }

    private let defaults = UserDefaults.standard

    private enum Key {
        static let resumePID = "resumePID"

        static let resumeRequestsSent = "resumeRequestsSent"
        static let resumeResponses = "resumeResponses"
        static let resumePositiveResponses = "resumePositiveResponses"
        static let resumeNegativeResponses = "resumeNegativeResponses"
        static let resumeTimeouts = "resumeTimeouts"
        static let resumeStartedAt = "resumeStartedAt"

        static let savedResults = "savedResults"
    }
    
    func saveResumePoint(
        session: ScanSession,
        statistics: SearchStatistics,
        scanStatistics: ScanStatistics,
        force: Bool = false
    ){
        if !force && (session.currentPID % 10 != 0) {
            return
        }

        defaults.set(session.currentPID, forKey: Key.resumePID)

        let requestStats = statistics
        
        defaults.set(requestStats.requestsSent, forKey: Key.resumeRequestsSent)
        defaults.set(requestStats.successfulResponses + requestStats.failedResponses, forKey: Key.resumeResponses)
        let stats = scanStatistics
        defaults.set(stats.positiveResponses, forKey: Key.resumePositiveResponses)
        defaults.set(stats.negativeResponses, forKey: Key.resumeNegativeResponses)
        defaults.set(stats.timeouts, forKey: Key.resumeTimeouts)
        defaults.set(stats.startedAt, forKey: Key.resumeStartedAt)

        refreshResumeAvailability()
    }
    
    func loadResumePoint(
        into session: ScanSession,
        scanStatistics: ScanStatistics ){

        session.currentPID = defaults.object(forKey: Key.resumePID) as? Int ?? 0

        let stats = scanStatistics
        stats.positiveResponses = defaults.object(forKey: Key.resumePositiveResponses) as? Int ?? 0
        stats.negativeResponses = defaults.object(forKey: Key.resumeNegativeResponses) as? Int ?? 0
        stats.timeouts = defaults.object(forKey: Key.resumeTimeouts) as? Int ?? 0
        stats.startedAt = defaults.object(forKey: Key.resumeStartedAt) as? Date
        stats.finishedAt = nil

        // Restore totalRequests if already known
        // (no reset of ScanStatistics here)

        refreshResumeAvailability()
    }
    
    func refreshResumeAvailability() {
        hasResumePoint =
            defaults.object(forKey: Key.resumePID) != nil
    }
    
    func clearResumePoint(session: ScanSession) {
        session.currentPID = 0
        session.searchStrategy.reset()
        defaults.removeObject(forKey: Key.resumePID)
        defaults.removeObject(forKey: Key.resumeRequestsSent)
        defaults.removeObject(forKey: Key.resumeResponses)
        defaults.removeObject(forKey: Key.resumePositiveResponses)
        defaults.removeObject(forKey: Key.resumeNegativeResponses)
        defaults.removeObject(forKey: Key.resumeTimeouts)
        defaults.removeObject(forKey: Key.resumeStartedAt)
        refreshResumeAvailability()
    }
    
    func saveResults(_ results: [ScanResult]) {
        guard let data = try? JSONEncoder().encode(results) else { return }
        defaults.set(data, forKey: Key.savedResults)
    }

    func loadResults() -> [ScanResult] {
        guard
            let data = defaults.data(forKey: Key.savedResults),
            let saved = try? JSONDecoder().decode([ScanResult].self, from: data)
        else {
            return []
        }

        return saved.sorted {
            ($0.header, $0.request) < ($1.header, $1.request)
        }
    }
    
    func clearSavedResults() {
        defaults.removeObject(forKey: Key.savedResults)
    }
    
}
