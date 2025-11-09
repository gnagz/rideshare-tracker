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
    @State private var includeImages = true

    var totalShifts: Int { shiftManager.activeShifts.count }
    var totalExpenses: Int { expenseManager.activeExpenses.count }
    var totalImages: Int {
        let shiftImages = shiftManager.shifts.reduce(0) { $0 + $1.imageAttachments.count }
        let expenseImages = expenseManager.expenses.reduce(0) { $0 + $1.imageAttachments.count }
        return shiftImages + expenseImages
    }
    
    var body: some View {
        VStack(spacing: 20) {
            
            VStack(spacing: 16) {
                Image(systemName: "externaldrive")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("Create Full Backup")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Create a complete backup of all your data including shifts, expenses, and preferences.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)
            }

            // Data Summary
            VStack(spacing: 8) {
                Text("Data to Backup")
                    .font(.headline)

                HStack(spacing: 8) {
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

                    DataSummaryCard(
                        icon: "photo.fill",
                        title: "Images",
                        count: totalImages,
                        color: .purple
                    )
                }

                // Include Images Toggle
                Toggle("Include Image Attachments", isOn: $includeImages)
                    .padding(.horizontal)
                    .padding(.top, 4)

                if !includeImages {
                    Text("⚠️ Image attachments will not be included in the backup")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal)
            .background(Color(.systemGroupedBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Button("Create Backup") {
                createBackup()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(totalShifts == 0 && totalExpenses == 0)
            
            Spacer()

            // Backup Info
            VStack(alignment: .leading, spacing: 8) {
                Label("Backup Details", systemImage: "info.circle")
                    .font(.headline)

                Text("• All shift data with complete history")
                Text("• All business expense records")
                Text("• User preferences and settings")
                if includeImages {
                    Text("• Image attachments (full-size + thumbnails)")
                    Text("• ZIP archive format with organized structure")
                } else {
                    Text("• JSON format (legacy, no images)")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGroupedBackground))
            .cornerRadius(8)
            .padding(.horizontal)
        }
        .fileExporter(
            isPresented: $showingShareSheet,
            document: backupURL.map { DocumentFile(url: $0) },
            contentType: includeImages ? .zip : .json,
            defaultFilename: backupURL?.lastPathComponent ?? (includeImages ? "backup.zip" : "backup.json")
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
        do {
            let url = try backupRestoreManager.createFullBackup(
                shifts: shiftManager.shifts,
                expenses: expenseManager.expenses,
                preferences: preferences,
                includeImages: includeImages
            )
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
    @State private var backupContainsImages = false
    
    var body: some View {
        VStack(spacing: 20) {

            VStack(spacing: 16) {
                Image(systemName: "externaldrive.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)

                Text("Restore from Backup")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Restore your data from a backup file (ZIP or legacy JSON) with flexible duplicate handling.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
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
                        .font(.subheadline)
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
            VStack(alignment: .leading, spacing: 8) {
                Label("Restore Details", systemImage: "info.circle")
                    .font(.headline)

                switch selectedRestoreAction {
                case .replaceAll:
                    Text("• Delete all current data")
                    Text("• Restore all records from backup")
                    Text("• Preferences are restored")
                    Text("⚠️ Consider creating a backup first when using Clear & Restore.")
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                        .padding(.top, 4)
                case .skipDuplicates:
                    Text("• Keep all current data")
                    Text("• Add only records that don't exist")
                    Text("• Preferences are restored")
                case .merge:
                    Text("• Keep all current data")
                    Text("• Update existing records from backup")
                    Text("• Add new records from backup")
                    Text("• Preferences are restored")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGroupedBackground))
            .cornerRadius(8)
            .padding(.horizontal)
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType.json, UTType.zip],
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
                var message = "\(actionDesc)\n\nBackup contains:\n• \(backup.shifts.count) shifts\n• \(backup.expenses?.count ?? 0) expenses"
                if backupContainsImages {
                    message += "\n• Image attachments"
                } else {
                    message += "\n\n⚠️ No images (legacy backup)"
                }
                message += "\n\nPreferences will be restored."
                return Text(message)
            } else {
                return Text("No backup data available")
            }
        }
    }
    
    private func handleRestore(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            do {
                // Detect if backup contains images (ZIP format)
                backupContainsImages = url.pathExtension.lowercased() == "zip"

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
