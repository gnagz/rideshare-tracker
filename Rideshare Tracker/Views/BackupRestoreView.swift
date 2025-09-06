//
//  BackupRestoreView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/26/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct BackupRestoreView: View {
    @EnvironmentObject var dataManager: ShiftDataManager
    @EnvironmentObject var expenseManager: ExpenseDataManager
    @EnvironmentObject var preferences: AppPreferences
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            TabView {
                BackupView()
                    .tabItem {
                        Image(systemName: "externaldrive.fill")
                        Text("Backup")
                    }
                    .environmentObject(dataManager)
                    .environmentObject(expenseManager)
                    .environmentObject(preferences)
                
                RestoreView()
                    .tabItem {
                        Image(systemName: "externaldrive.badge.plus")
                        Text("Restore")
                    }
                    .environmentObject(dataManager)
                    .environmentObject(expenseManager)
                    .environmentObject(preferences)
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
    @EnvironmentObject var dataManager: ShiftDataManager
    @EnvironmentObject var expenseManager: ExpenseDataManager
    @EnvironmentObject var preferences: AppPreferences
    
    @State private var showingShareSheet = false
    @State private var backupURL: URL?
    @State private var showingBackupAlert = false
    @State private var backupMessage = ""
    
    var totalShifts: Int { dataManager.activeShifts.count }
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
        let backupURL = preferences.createFullBackup(shifts: dataManager.shifts, expenses: expenseManager.expenses)
        
        if let url = backupURL {
            self.backupURL = url
            showingShareSheet = true
        } else {
            backupMessage = "Failed to create backup file"
            showingBackupAlert = true
        }
    }
}

struct RestoreView: View {
    @EnvironmentObject var dataManager: ShiftDataManager
    @EnvironmentObject var expenseManager: ExpenseDataManager
    @EnvironmentObject var preferences: AppPreferences
    
    @State private var showingFilePicker = false
    @State private var showingRestoreAlert = false
    @State private var restoreMessage = ""
    @State private var restoreAlertTitle = ""
    @State private var showingConfirmation = false
    @State private var pendingBackupData: BackupData?
    
    var body: some View {
        VStack(spacing: 20) {
            
            VStack(spacing: 16) {
                Image(systemName: "externaldrive.badge.plus.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("Restore from Backup")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Restore your data from a JSON backup file. This will replace all current data.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("Select Backup File") {
                    showingFilePicker = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            
            Spacer()
            
            // Warning Section
            VStack(alignment: .leading, spacing: 12) {
                Label("Important", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("• This will replace ALL existing data")
                    Text("• Current shifts and expenses will be lost")
                    Text("• User preferences will be updated")
                    Text("• This action cannot be undone")
                    
                    Text("Consider creating a backup of current data before restoring.")
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                        .padding(.top, 4)
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
                    .stroke(Color.orange, lineWidth: 1)
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
            Button("Replace All Data", role: .destructive) {
                performRestore()
            }
        } message: {
            if let backup = pendingBackupData {
                Text("This will replace all current data with:\n\n\(backup.shifts.count) shifts\n\(backup.expenses?.count ?? 0) expenses\n\nThis cannot be undone.")
            }
        }
    }
    
    private func handleRestore(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            let importResult = AppPreferences.importData(from: url)
            switch importResult {
            case .success(let backupData):
                pendingBackupData = backupData
                showingConfirmation = true
                
            case .failure(let error):
                restoreAlertTitle = "Restore Failed"
                restoreMessage = error.localizedDescription
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
        
        // Clear existing data
        dataManager.shifts.removeAll()
        expenseManager.expenses.removeAll()
        
        // Restore shifts
        for shift in backupData.shifts {
            dataManager.addShift(shift)
        }
        
        // Restore expenses
        if let expenses = backupData.expenses {
            for expense in expenses {
                expenseManager.addExpense(expense)
            }
        }
        
        // Restore preferences
        preferences.importPreferences(backupData.preferences)
        
        restoreAlertTitle = "Restore Successful"
        restoreMessage = "Successfully restored:\n\n\(backupData.shifts.count) shifts\n\(backupData.expenses?.count ?? 0) expenses\n\nPreferences have been updated."
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