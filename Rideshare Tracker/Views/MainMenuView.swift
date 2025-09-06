//
//  MainMenuView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/26/25.
//

import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var dataManager: ShiftDataManager
    @EnvironmentObject var expenseManager: ExpenseDataManager
    @EnvironmentObject var preferences: AppPreferences
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showingPreferences = false
    @State private var showingIncrementalSync = false
    @State private var showingImportExport = false
    @State private var showingBackupRestore = false
    @State private var showingAppInfo = false
    
    var body: some View {
        NavigationView {
            menuContent
                .navigationTitle("Menu")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
        }
    }
    
    private var menuContent: some View {
        List {
            Section {
                MenuRow(
                    icon: "gearshape.fill",
                    title: "Preferences",
                    subtitle: "App settings and configuration",
                    color: .blue
                ) {
                    showingPreferences = true
                }
                
                MenuRow(
                    icon: "arrow.trianglehead.2.clockwise.rotate.90.icloud.fill",
                    title: "Incremental Cloud Sync",
                    subtitle: "Auto-sync data across devices via iCloud",
                    color: .cyan
                ) {
                    showingIncrementalSync = true
                }
                
                MenuRow(
                    icon: "square.and.arrow.up.fill",
                    title: "Import/Export",
                    subtitle: "CSV import and export with date ranges",
                    color: .green
                ) {
                    showingImportExport = true
                }
                
                MenuRow(
                    icon: "externaldrive.fill",
                    title: "Backup/Restore",
                    subtitle: "Full data backup and restore (JSON)",
                    color: .orange
                ) {
                    showingBackupRestore = true
                }
                
                MenuRow(
                    icon: "info.circle.fill",
                    title: "App Info",
                    subtitle: "Version and build information",
                    color: .purple
                ) {
                    showingAppInfo = true
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .sheet(isPresented: $showingPreferences) {
            PreferencesView()
                .environmentObject(dataManager)
                .environmentObject(expenseManager)
                .environmentObject(preferences)
        }
        .sheet(isPresented: $showingIncrementalSync) {
            IncrementalSyncView()
                .environmentObject(dataManager)
                .environmentObject(expenseManager)
                .environmentObject(preferences)
        }
        .sheet(isPresented: $showingImportExport) {
            ImportExportView()
                .environmentObject(dataManager)
                .environmentObject(expenseManager)
                .environmentObject(preferences)
        }
        .sheet(isPresented: $showingBackupRestore) {
            BackupRestoreView()
                .environmentObject(dataManager)
                .environmentObject(expenseManager)
                .environmentObject(preferences)
        }
        .sheet(isPresented: $showingAppInfo) {
            AppInfoView()
                .environmentObject(preferences)
        }
    }
}

struct MenuRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}