//
//  MainTabView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/23/25.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var preferences: AppPreferences
    @EnvironmentObject var dataManager: ShiftDataManager
    @EnvironmentObject var expenseManager: ExpenseDataManager
    
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Image(systemName: "car.fill")
                    Text("Shifts")
                }
                .environmentObject(preferences)
                .environmentObject(dataManager)
                .environmentObject(expenseManager)
            
            ExpenseListView()
                .tabItem {
                    Image(systemName: "receipt.fill")
                    Text("Expenses")
                }
                .environmentObject(preferences)
                .environmentObject(dataManager)
                .environmentObject(expenseManager)
        }
    }
}