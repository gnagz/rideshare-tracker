//
//  BackupRestoreView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/26/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct BackupRestoreView: View {
    @EnvironmentObject var shiftManager: ShiftDataManager
    @EnvironmentObject var expenseManager: ExpenseDataManager
    @EnvironmentObject var preferencesManager: PreferencesManager
    @Environment(\.presentationMode) var presentationMode

    private var preferences: AppPreferences { preferencesManager.preferences }

    var body: some View {
        NavigationView {
            TabView {
                BackupView()
                    .tabItem {
                        Image(systemName: "externaldrive.fill")
                        Text("Backup")
                    }
                    .environmentObject(shiftManager)
                    .environmentObject(expenseManager)
                    .environmentObject(preferencesManager)
                
                RestoreView()
                    .tabItem {
                        Image(systemName: "externaldrive.badge.plus")
                        Text("Restore")
                    }
                    .environmentObject(shiftManager)
                    .environmentObject(expenseManager)
                    .environmentObject(preferencesManager)
            }
            .navigationTitle("Backup/Restore")
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
}

struct BackupView: View {
    @EnvironmentObject var shiftManager: ShiftDataManager
    @EnvironmentObject var expenseManager: ExpenseDataManager
    @EnvironmentObject var preferencesManager: PreferencesManager
    @EnvironmentObject var backupRestoreManager: BackupRestoreManager

    private var preferences: AppPreferences { preferencesManager.preferences }

    @State private var showingShareSheet = false
    @State private var backupURL: URL?
    @State private var showingBackupAlert = false
    @State private var backupMessage = ""
    
    var totalShifts: Int { shiftManager.activeShifts.count }
    var totalExpenses: Int { expenseManager.activeExpenses.count }
    
    var body: some View {
        VStack(spacing: 20) {
            
            VStack(spacing: 16) {
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Create Full Backup")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Create a complete backup of all your data including shifts, expenses, and preferences in JSON format.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Data Summary
            VStack(spacing: 12) {
                Text("Data to Backup")
                    .font(.headline)
                
                HStack(spacing: 20) {
                    DataSummaryCard(
                        icon: "car.fill",
                        title: "Shifts",
                        count: totalShifts,
                        color: .blue
                    )
                    
                    DataSummaryCard(
                        icon: "receipt.fill",
                        title: "Expenses",
                        count: totalExpenses,
                        color: .green
                    )
                }
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Button("Create Backup") {
                createBackup()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(totalShifts == 0 && totalExpenses == 0)
            
            // Backup Info
            VStack(alignment: .leading, spacing: 8) {
                Label("Backup Details", systemImage: "info.circle")
                    .font(.headline)
                
                Text("• All shift data with complete history")
                Text("• All business expense records")
                Text("• User preferences and settings")
                Text("• JSON format for data integrity")
                Text("• Compatible with future app versions")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGroupedBackground))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .fileExporter(
            isPresented: $showingShareSheet,
            document: backupURL.map { DocumentFile(url: $0) },
            contentType: .json,
            defaultFilename: backupURL?.lastPathComponent ?? "backup.json"
        ) { result in
            switch result {
            case .success(let url):
                backupMessage = "Backup saved to: \(url.lastPathComponent)"
                showingBackupAlert = true
            case .failure(let error):
                backupMessage = "Backup failed: \(error.localizedDescription)"
                showingBackupAlert = true
            }
        }
        .alert("Backup Result", isPresented: $showingBackupAlert) {
            Button("OK") { }
        } message: {
            Text(backupMessage)
        }
    }
    
    private func createBackup() {
        // Always include all data for full backup
        do {
            let url = try backupRestoreManager.createFullBackup(shifts: shiftManager.shifts, expenses: expenseManager.expenses, preferences: preferences)
            self.backupURL = url
            showingShareSheet = true
        } catch {
            backupMessage = backupRestoreManager.lastError?.localizedDescription ?? "Failed to create backup file"
            showingBackupAlert = true
        }
    }
}

struct RestoreView: View {
    @EnvironmentObject var shiftManager: ShiftDataManager
    @EnvironmentObject var expenseManager: ExpenseDataManager
    @EnvironmentObject var preferencesManager: PreferencesManager

    private var preferences: AppPreferences { preferencesManager.preferences }
    @EnvironmentObject var backupRestoreManager: BackupRestoreManager

    @State private var showingFilePicker = false
    @State private var showingRestoreAlert = false
    @State private var restoreMessage = ""
    @State private var restoreAlertTitle = ""
    @State private var showingConfirmation = false
    @State private var pendingBackupData: BackupData?
    @State private var selectedRestoreAction: RestoreAction = .merge
    
    var body: some View {
        VStack(spacing: 20) {

            VStack(spacing: 16) {
                Image(systemName: "externaldrive.badge.plus.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)

                Text("Restore from Backup")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Restore your data from a JSON backup file with flexible duplicate handling.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Restore Action Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Restore Method")
                        .font(.headline)

                    Picker("Restore Method", selection: $selectedRestoreAction) {
                        ForEach(RestoreAction.allCases, id: \.self) { action in
                            Text(action.rawValue).tag(action)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(selectedRestoreAction.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal)

                Button("Select Backup File") {
                    showingFilePicker = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            
            Spacer()
            
            // Info Section
            VStack(alignment: .leading, spacing: 12) {
                Label("Restore Options", systemImage: "info.circle.fill")
                    .font(.headline)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 8) {
                    Text("• Clear & Restore: Delete all current data")
                    Text("• Restore Missing: Add only new records")
                    Text("• Merge & Restore: Update existing + add new")
                    Text("• Preferences are always restored")

                    if selectedRestoreAction == .replaceAll {
                        Text("⚠️ Consider creating a backup first when using Clear & Restore.")
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                            .padding(.top, 4)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGroupedBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedRestoreAction == .replaceAll ? Color.orange : Color.blue, lineWidth: 1)
            )
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            handleRestore(result)
        }
        .alert(restoreAlertTitle, isPresented: $showingRestoreAlert) {
            Button("OK") { }
        } message: {
            Text(restoreMessage)
        }
        .alert("Confirm Restore", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingBackupData = nil
            }
            Button(selectedRestoreAction.rawValue, role: selectedRestoreAction == .replaceAll ? .destructive : .none) {
                performRestore()
            }
        } message: {
            if let backup = pendingBackupData {
                let actionDesc = selectedRestoreAction.description
                Text("\(actionDesc)\n\nBackup contains:\n• \(backup.shifts.count) shifts\n• \(backup.expenses?.count ?? 0) expenses\n\nPreferences will be restored.")
            }
        }
    }
    
    private func handleRestore(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            do {
                let backupData = try backupRestoreManager.loadBackup(from: url)
                pendingBackupData = backupData
                showingConfirmation = true
            } catch {
                restoreAlertTitle = "Restore Failed"
                restoreMessage = backupRestoreManager.lastError?.localizedDescription ?? "Unknown error"
                showingRestoreAlert = true
            }

        case .failure(let error):
            restoreAlertTitle = "Restore Failed"
            restoreMessage = "Failed to access file: \(error.localizedDescription)"
            showingRestoreAlert = true
        }
    }
    
    private func performRestore() {
        guard let backupData = pendingBackupData else { return }

        // Use BackupRestoreManager for all restore logic
        let result = backupRestoreManager.restoreFromBackup(
            backupData: backupData,
            shiftManager: shiftManager,
            expenseManager: expenseManager,
            preferencesManager: preferencesManager,
            action: selectedRestoreAction
        )

        // Build detailed result message
        var message = "Restore completed using '\(selectedRestoreAction.rawValue)':\n\n"

        message += "Shifts:\n"
        if result.shiftsAdded > 0 {
            message += "  • Added: \(result.shiftsAdded)\n"
        }
        if result.shiftsUpdated > 0 {
            message += "  • Updated: \(result.shiftsUpdated)\n"
        }
        if result.shiftsSkipped > 0 {
            message += "  • Skipped: \(result.shiftsSkipped)\n"
        }

        message += "\nExpenses:\n"
        if result.expensesAdded > 0 {
            message += "  • Added: \(result.expensesAdded)\n"
        }
        if result.expensesUpdated > 0 {
            message += "  • Updated: \(result.expensesUpdated)\n"
        }
        if result.expensesSkipped > 0 {
            message += "  • Skipped: \(result.expensesSkipped)\n"
        }

        message += "\nPreferences have been restored."

        restoreAlertTitle = "Restore Successful"
        restoreMessage = message
        showingRestoreAlert = true

        pendingBackupData = nil
    }
}

struct DataSummaryCard: View {
    let icon: String
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}
