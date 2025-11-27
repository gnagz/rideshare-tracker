//
//  MainTabView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/23/25.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var preferencesManager: PreferencesManager
    @EnvironmentObject var dataManager: ShiftDataManager
    @EnvironmentObject var expenseManager: ExpenseDataManager

    private var preferences: AppPreferences { preferencesManager.preferences }

    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Image(systemName: "car.fill")
                    Text("Shifts")
                }
                .environmentObject(preferencesManager)
                .environmentObject(dataManager)
                .environmentObject(expenseManager)

            ExpenseListView()
                .tabItem {
                    Image(systemName: "receipt.fill")
                    Text("Expenses")
                }
                .environmentObject(preferencesManager)
                .environmentObject(dataManager)
                .environmentObject(expenseManager)

            YTDSummaryView()
                .tabItem {
                    Image(systemName: "chart.bar.doc.horizontal")
                    Text("YTD Summary")
                }
                .environmentObject(preferencesManager)
                .environmentObject(dataManager)
                .environmentObject(expenseManager)
        }
    }
}