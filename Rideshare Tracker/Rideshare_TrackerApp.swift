//
//  Rideshare_TrackerApp.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//  Optimized for iOS Universal (iPhone, iPad, Mac) on 8/19/25
//

import SwiftUI

@main
struct RideshareTrackerApp: App {
    @StateObject private var preferences = AppPreferences.shared
    @StateObject private var dataManager = ShiftDataManager.shared
    @StateObject private var expenseManager = ExpenseDataManager.shared
    @StateObject private var syncLifecycleManager = SyncLifecycleManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(preferences)
                .environmentObject(dataManager)
                .environmentObject(expenseManager)
                .environmentObject(syncLifecycleManager)
        }
    }
}
