//
//  Rideshare_TrackerApp.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//

import SwiftUI

@main
struct RideshareTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AppPreferences())
                .environmentObject(ShiftDataManager())
        }
    }
}
