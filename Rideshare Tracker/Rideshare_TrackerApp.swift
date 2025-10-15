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
    @State private var showTestNameAlert = false
    @State private var testName = ""

    init() {
        // Check if app was launched with a test name
        if let testNameIndex = CommandLine.arguments.firstIndex(of: "-testName"),
           testNameIndex + 1 < CommandLine.arguments.count {
            let name = CommandLine.arguments[testNameIndex + 1]
            _testName = State(initialValue: name)
            _showTestNameAlert = State(initialValue: true)
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(preferences)
                .environmentObject(dataManager)
                .environmentObject(expenseManager)
                .environmentObject(syncLifecycleManager)
                .alert("Running UI Test", isPresented: $showTestNameAlert) {
                    Button("OK") {
                        showTestNameAlert = false
                    }
                } message: {
                    Text(testName)
                }
        }
    }
}
