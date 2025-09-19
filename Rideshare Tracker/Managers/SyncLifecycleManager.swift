//
//  SyncLifecycleManager.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/30/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class SyncLifecycleManager: ObservableObject {
    static let shared = SyncLifecycleManager()
    
    private let cloudSyncManager = CloudSyncManager.shared
    private let preferences = AppPreferences.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var lastAutoSyncDate: Date?
    
    private init() {
        setupAppLifecycleObservers()
    }
    
    private func setupAppLifecycleObservers() {
        // Listen for app entering background
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                Task {
                    await self?.performAutoSyncIfNeeded(trigger: .appBackground)
                }
            }
            .store(in: &cancellables)
        
        // Listen for app becoming active
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task {
                    await self?.checkForIncomingSyncChanges()
                }
            }
            .store(in: &cancellables)
        
        // Listen for app termination
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                Task {
                    await self?.performAutoSyncIfNeeded(trigger: .appTermination)
                }
            }
            .store(in: &cancellables)
    }
    
    func performAutoSyncIfNeeded(trigger: SyncTrigger) async {
        // Only sync if incremental sync is enabled
        guard preferences.incrementalSyncEnabled else { return }
        
        // Check if we should sync based on frequency setting
        guard shouldSyncNow(for: trigger) else { return }
        
        do {
            let syncResult = try await cloudSyncManager.performIncrementalSync(
                shifts: ShiftDataManager.shared.shifts,
                expenses: ExpenseDataManager.shared.expenses,
                lastSyncDate: preferences.lastIncrementalSyncDate
            )
            
            // Update local data with merged results
            await MainActor.run {
                ShiftDataManager.shared.shifts = syncResult.mergedShifts
                ShiftDataManager.shared.saveShifts()
                
                ExpenseDataManager.shared.expenses = syncResult.mergedExpenses
                ExpenseDataManager.shared.saveExpenses()
                
                preferences.lastIncrementalSyncDate = Date()
                lastAutoSyncDate = Date()
                preferences.savePreferences()
                
                print("Auto-sync completed successfully (\(trigger.rawValue)): \(syncResult.mergedShifts.count) shifts, \(syncResult.mergedExpenses.count) expenses")
            }
            
        } catch {
            print("Auto-sync failed (\(trigger.rawValue)): \(error.localizedDescription)")
            // Don't show UI errors for background sync - just log them
        }
    }
    
    private func checkForIncomingSyncChanges() async {
        // Only check if incremental sync is enabled
        guard preferences.incrementalSyncEnabled else { return }
        
        // This could be enhanced to detect if cloud data is newer
        // and prompt user to sync, but for now we'll just perform a sync
        await performAutoSyncIfNeeded(trigger: .appForeground)
    }
    
    private func shouldSyncNow(for trigger: SyncTrigger) -> Bool {
        let syncFrequency = preferences.syncFrequency
        let lastSyncDate = preferences.lastIncrementalSyncDate ?? Date.distantPast
        let timeSinceLastSync = Date().timeIntervalSince(lastSyncDate)
        
        switch syncFrequency {
        case "Immediate":
            return true // Always sync
            
        case "Hourly":
            return timeSinceLastSync > 3600 // 1 hour
            
        case "Daily":
            return timeSinceLastSync > 86400 // 24 hours
            
        default:
            return true // Default to immediate
        }
    }
}

enum SyncTrigger: String, CaseIterable {
    case appBackground = "App Background"
    case appForeground = "App Foreground"
    case appTermination = "App Termination"
    case manual = "Manual"
}