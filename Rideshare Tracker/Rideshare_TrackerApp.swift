//
//  Rideshare_TrackerApp.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//  Updated for macOS support on 8/13/25
//

import SwiftUI

@main
struct RideshareTrackerApp: App {
    @StateObject private var preferences = AppPreferences()
    @StateObject private var dataManager = ShiftDataManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(preferences)
                .environmentObject(dataManager)
        }
        #if os(macOS)
        .defaultSize(width: 1000, height: 700)
        #endif
        
        #if os(macOS)
        Settings {
            PreferencesView()
                .environmentObject(preferences)
                .environmentObject(dataManager)
                .frame(width: 600, height: 500)
        }
        #endif
    }
}
