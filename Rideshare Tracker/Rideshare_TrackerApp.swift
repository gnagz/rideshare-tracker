//
//  Rideshare_TrackerApp.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//  Optimized for iOS Universal (iPhone, iPad, Mac) on 8/19/25
//

import SwiftUI
import AudioToolbox

@main
struct RideshareTrackerApp: App {
    @StateObject private var preferencesManager = PreferencesManager.shared
    @StateObject private var dataManager = ShiftDataManager.shared
    @StateObject private var expenseManager = ExpenseDataManager.shared
    @StateObject private var syncLifecycleManager = SyncLifecycleManager.shared
    @StateObject private var importExportManager = ImportExportManager.shared
    @StateObject private var backupRestoreManager = BackupRestoreManager.shared
    @State private var showTestNameAlert = false
    @State private var testName = ""
    @State private var showTestOperationAlert = false
    @State private var operationMessage = ""

    init() {
        print("🚀🚀🚀 RIDESHARE TRACKER APP LAUNCHING 🚀🚀🚀")
        // Check if app was launched with a test name
        if let testNameIndex = CommandLine.arguments.firstIndex(of: "-testName"),
           testNameIndex + 1 < CommandLine.arguments.count {
            let name = CommandLine.arguments[testNameIndex + 1]
            _testName = State(initialValue: name)
            _showTestNameAlert = State(initialValue: true)
            print("🧪 Test name: \(name)")
            debugPrint("DEBUG 🧪 Test name: \(name)")
        }

        // Check if app was launched with a test operation message
        if let operationIndex = CommandLine.arguments.firstIndex(of: "-testOperation"),
           operationIndex + 1 < CommandLine.arguments.count {
            let message = CommandLine.arguments[operationIndex + 1]
            _operationMessage = State(initialValue: message)
            _showTestOperationAlert = State(initialValue: true)
            debugPrint("DEBUG 🧪 Operation: \(message)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(preferencesManager)
                .environmentObject(dataManager)
                .environmentObject(expenseManager)
                .environmentObject(syncLifecycleManager)
                .environmentObject(importExportManager)
                .environmentObject(backupRestoreManager)
                .alert("Running UI Test", isPresented: $showTestNameAlert) {
                    Button("OK") {
                        showTestNameAlert = false
                    }
                } message: {
                    Text(testName)
                }
                .onChange(of: showTestNameAlert) { newValue in
                    if newValue {
                        // Play a distinct alert sound when test starts
                        // Sound ID 1054 = Alarm (loud, urgent sound to alert when test begins)
                        AudioServicesPlaySystemSound(1054)
                    }
                }
                .alert("UI Test Operation", isPresented: $showTestOperationAlert) {
                    Button("OK") {
                        showTestOperationAlert = false
                    }
                } message: {
                    Text(operationMessage)
                }
        }
    }
    
}
