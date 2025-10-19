//
//  IncrementalSyncView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/30/25.
//

import SwiftUI

struct IncrementalSyncView: View {
    @EnvironmentObject var preferencesManager: PreferencesManager
    @EnvironmentObject var dataManager: ShiftDataManager
    @EnvironmentObject var expenseManager: ExpenseDataManager
    @Environment(\.presentationMode) var presentationMode

    private var preferences: AppPreferences { preferencesManager.preferences }

    private var syncEnabledBinding: Binding<Bool> {
        Binding(
            get: { preferences.incrementalSyncEnabled },
            set: { newValue in
                if newValue && preferences.lastIncrementalSyncDate == nil {
                    // First time enabling - show initial sync confirmation
                    showingInitialSyncConfirmation = true
                } else {
                    // Already synced before or disabling
                    preferencesManager.preferences.incrementalSyncEnabled = newValue
                    preferencesManager.savePreferences()
                }
            }
        )
    }

    @StateObject private var cloudSyncManager = CloudSyncManager.shared
    @StateObject private var syncLifecycleManager = SyncLifecycleManager.shared
    @State private var showingSyncAlert = false
    @State private var syncAlertMessage = ""
    @State private var showingInitialSyncConfirmation = false
    @State private var showingCleanupConfirmation = false
    @State private var isPerformingCleanup = false
    
    enum SyncFrequency: String, CaseIterable {
        case immediate = "Immediate"
        case hourly = "Hourly"
        case daily = "Daily"
        
        var description: String {
            switch self {
            case .immediate:
                return "Sync every time you close the app (recommended)"
            case .hourly:
                return "Sync once per hour when you close the app"
            case .daily:
                return "Sync once per day when you close the app"
            }
        }
    }
    
    var body: some View {
        EmptyView()
        /*NavigationView {
            ScrollView {
               VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.icloud.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Incremental Cloud Sync")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Keep your data synchronized across all devices and protected from loss")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Benefits Section
                    VStack(spacing: 20) {
                        BenefitCard(
                            icon: "laptopcomputer.and.iphone",
                            title: "Multi-Device Sync",
                            description: "Use the app seamlessly across iPhone, iPad, and Mac. Changes made on one device instantly appear on all others.",
                            color: .blue
                        )
                        
                        BenefitCard(
                            icon: "shield.checkered",
                            title: "Ultimate Data Protection",
                            description: "Never lose your data again. If your device is lost or destroyed, your new device will have 100% of your data with zero loss.",
                            color: .green
                        )
                        
                        BenefitCard(
                            icon: "bolt.fill",
                            title: "Automatic & Effortless",
                            description: "Once enabled, sync happens automatically in the background. No manual exports or imports needed.",
                            color: .orange
                        )
                    }
                    .padding(.horizontal)
                    
                    // Settings Section
                    VStack(spacing: 16) {
                        Text("Sync Settings")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            // iCloud Availability Warning (show when sync enabled but iCloud unavailable)
                            if preferences.incrementalSyncEnabled && !cloudSyncManager.isICloudAvailable {
                                VStack(spacing: 12) {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                        Text("iCloud Sync Unavailable")
                                            .font(.headline)
                                            .foregroundColor(.orange)
                                        Spacer()
                                    }
                                    
                                    Text("iCloud sync is currently not available. This could be due to missing iCloud setup, no internet connection, or app configuration. All your data is still safely stored locally.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                                .padding(.horizontal)
                                
                                Divider()
                                    .padding(.horizontal)
                            }
                            
                            // Enable/Disable Toggle
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Enable Incremental Cloud Sync")
                                        .font(.headline)
                                    Text("Sync your data to iCloud automatically")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()

                                Toggle("", isOn: syncEnabledBinding)
                            }
                            .padding()
                            .background(Color(.systemGroupedBackground))
                            
                            if preferences.incrementalSyncEnabled {
                                Divider()
                                    .padding(.leading)
                                
                                // Frequency Picker
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Sync Frequency")
                                        .font(.headline)
                                    
                                    ForEach(SyncFrequency.allCases, id: \.self) { frequency in
                                        HStack {
                                            Button(action: {
                                                preferencesManager.preferences.syncFrequency = frequency.rawValue
                                            }) {
                                                HStack {
                                                    Image(systemName: preferences.syncFrequency == frequency.rawValue ? "checkmark.circle.fill" : "circle")
                                                        .foregroundColor(preferences.syncFrequency == frequency.rawValue ? .blue : .secondary)
                                                    
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(frequency.rawValue)
                                                            .font(.body)
                                                            .foregroundColor(.primary)
                                                        Text(frequency.description)
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                    
                                                    Spacer()
                                                }
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                }
                                .padding()
                                .background(Color(.systemGroupedBackground))
                                
                                Divider()
                                    .padding(.leading)
                                
                                // Sync Status
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Sync Status")
                                        .font(.headline)
                                        .accessibilityIdentifier("sync_status_section")
                                    
                                    HStack {
                                        Text("Last Sync")
                                        Spacer()
                                        Text(formatLastSyncDate())
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack {
                                        Text("Sync Location")
                                        Spacer()
                                        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                                           ProcessInfo.processInfo.arguments.contains("-testing") ||
                                           NSClassFromString("XCTestCase") != nil ||
                                           Bundle.main.bundlePath.contains("xctest") {
                                            Label("Local Test Storage", systemImage: "folder.fill")
                                                .foregroundColor(.green)
                                                .font(.caption)
                                        } else {
                                            Label("iCloud Drive", systemImage: "icloud.fill")
                                                .foregroundColor(.blue)
                                                .font(.caption)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color(.systemGroupedBackground))
                                
                                Divider()
                                    .padding(.leading)
                                
                                // Manual Sync Button
                                Button(action: performManualSync) {
                                    HStack {
                                        if cloudSyncManager.isSyncing {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                            Text("Syncing...")
                                        } else {
                                            Image(systemName: "arrow.triangle.2.circlepath")
                                            Text("Sync Now")
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .disabled(cloudSyncManager.isSyncing || !cloudSyncManager.isICloudAvailable)
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("manual_sync_button")
                                .padding()
                                .background(Color(.systemGroupedBackground))
                                
                                Divider()
                                    .padding(.leading)
                                
                                // Advanced Section
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Advanced")
                                        .font(.headline)
                                    
                                    Text("Clean up deleted records that are still stored in iCloud. Only use this after all your devices have been synchronized.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    Button(action: { showingCleanupConfirmation = true }) {
                                        HStack {
                                            if isPerformingCleanup {
                                                ProgressView()
                                                    .scaleEffect(0.8)
                                                Text("Cleaning...")
                                            } else {
                                                Image(systemName: "trash.circle")
                                                Text("Permanently Delete from Cloud")
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .disabled(isPerformingCleanup || cloudSyncManager.isSyncing)
                                    .buttonStyle(.bordered)
                                    .foregroundColor(.red)
                                }
                                .padding()
                                .background(Color(.systemGroupedBackground))
                            }
                        }
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // How It Works Section
                    VStack(spacing: 16) {
                        Text("How It Works")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HowItWorksStep(
                                number: 1,
                                title: "Automatic Sync",
                                description: "When you close the app, it automatically saves any changes to your personal iCloud Drive folder."
                            )
                            
                            HowItWorksStep(
                                number: 2,
                                title: "Smart Detection",
                                description: "When you open the app on any device, it checks for newer data and asks if you'd like to sync."
                            )
                            
                            HowItWorksStep(
                                number: 3,
                                title: "Seamless Integration",
                                description: "Your data stays perfectly synchronized across all devices without any manual work."
                            )
                        }
                        .padding()
                        .background(Color(.systemGroupedBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Requirements Section
                    VStack(spacing: 16) {
                        Text("Requirements")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .accessibilityIdentifier("requirement_checkmark")
                                Text("iCloud account signed in to this device")
                            }
                            
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .accessibilityIdentifier("requirement_checkmark")
                                Text("iCloud Drive enabled in Settings")
                            }
                            
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .accessibilityIdentifier("requirement_checkmark")
                                Text("Internet connection for syncing")
                            }
                        }
                        .padding()
                        .background(Color(.systemGroupedBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .font(.caption)
                    }
                    
                    Spacer(minLength: 20)
                }
            }
            .navigationTitle("Cloud Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .alert("Sync Result", isPresented: $showingSyncAlert) {
            Button("OK") { }
        } message: {
            Text(syncAlertMessage)
        }
        .alert("Initial Sync Required", isPresented: $showingInitialSyncConfirmation) {
            Button("Cancel", role: .cancel) {
                // User cancelled - don't enable sync
            }
            Button("Upload All Data") {
                performInitialSync()
            }
        } message: {
            Text("This will upload all your existing data to iCloud:\n\n• \(dataManager.activeShifts.count) shifts\n• \(expenseManager.activeExpenses.count) expenses\n• All preferences\n\nThis may take a moment and requires an internet connection.")
        }
        .alert("⚠️ Permanent Deletion Warning", isPresented: $showingCleanupConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Permanently Delete", role: .destructive) {
                performCloudCleanup()
            }
        } message: {
            Text("This will PERMANENTLY delete all previously deleted records from iCloud storage across ALL devices.\n\n⚠️ IMPORTANT: Only proceed if all your devices have been successfully synchronized. Deleted records cannot be recovered after this action.\n\nThis helps reduce storage usage but is irreversible.")
        }
        .overlay(
            Group {
                if cloudSyncManager.isSyncing && preferences.lastIncrementalSyncDate == nil {
                    InitialSyncProgressView(
                        isVisible: .constant(cloudSyncManager.isSyncing),
                        totalShifts: dataManager.activeShifts.count,
                        totalExpenses: expenseManager.activeExpenses.count
                    )
                }
            }
        )
        .onChange(of: syncLifecycleManager.lastSyncError) { newValue in
            if let error = newValue {
                syncAlertMessage = "Sync Error: \(error.localizedDescription)"
                showingSyncAlert = true
                syncLifecycleManager.lastSyncError = nil
            }
        }*/
    }
    
    /*private func formatLastSyncDate() -> String {
        guard let lastSync = preferences.lastIncrementalSyncDate else {
            return "Never"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastSync, relativeTo: Date())
    }
    
    private func performInitialSync() {
        Task {
            do {
                // Migrate existing data to add sync metadata
                await MainActor.run {
                    migrateExistingDataToSyncFormat()
                }
                
                // Perform real iCloud sync
                try await cloudSyncManager.performInitialSync(
                    shifts: dataManager.shifts,
                    expenses: expenseManager.expenses
                )
                
                // Enable sync and mark as completed on main thread
                await MainActor.run {
                    preferencesManager.preferences.incrementalSyncEnabled = true
                    preferencesManager.preferences.lastIncrementalSyncDate = Date()
                    preferencesManager.savePreferences()
                    
                    // Clean up any local soft-deleted records after successful sync
                    dataManager.cleanupDeletedShifts()
                    expenseManager.cleanupDeletedExpenses()
                    
                    syncAlertMessage = "Initial sync completed successfully!\n\n\(dataManager.activeShifts.count) shifts and \(expenseManager.activeExpenses.count) expenses are now synchronized to iCloud."
                    showingSyncAlert = true
                }
                
            } catch {
                await MainActor.run {
                    syncAlertMessage = "Initial sync failed: \(error.localizedDescription)"
                    showingSyncAlert = true
                }
            }
        }
    }
    
    private func performManualSync() {
        Task {
            do {
                // Perform real incremental sync
                let syncResult = try await cloudSyncManager.performIncrementalSync(
                    shifts: dataManager.shifts,
                    expenses: expenseManager.expenses,
                    lastSyncDate: preferences.lastIncrementalSyncDate
                )
                
                // Update local data with merged results
                await MainActor.run {
                    dataManager.shifts = syncResult.mergedShifts
                    dataManager.saveShifts()
                    
                    expenseManager.expenses = syncResult.mergedExpenses
                    expenseManager.saveExpenses()
                    
                    // Clean up any local soft-deleted records after successful sync
                    dataManager.cleanupDeletedShifts()
                    expenseManager.cleanupDeletedExpenses()
                    
                    preferencesManager.preferences.lastIncrementalSyncDate = Date()
                    preferencesManager.savePreferences()
                    
                    syncAlertMessage = "Sync completed successfully!\n\nSynchronized \(syncResult.mergedShifts.count) shifts and \(syncResult.mergedExpenses.count) expenses."
                    showingSyncAlert = true
                }
                
            } catch {
                await MainActor.run {
                    syncAlertMessage = "Sync failed: \(error.localizedDescription)"
                    showingSyncAlert = true
                }
            }
        }
    }
    
    private func performCloudCleanup() {
        isPerformingCleanup = true
        Task {
            do {
                try await cloudSyncManager.permanentlyDeleteFromCloud()
                
                await MainActor.run {
                    isPerformingCleanup = false
                    syncAlertMessage = "Cloud cleanup completed successfully!\n\nDeleted records have been permanently removed from iCloud storage."
                    showingSyncAlert = true
                }
                
            } catch {
                await MainActor.run {
                    isPerformingCleanup = false
                    syncAlertMessage = "Cloud cleanup failed: \(error.localizedDescription)"
                    showingSyncAlert = true
                }
            }
        }
    }
    
    private func migrateExistingDataToSyncFormat() {
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        
        // Migrate all existing shifts
        for i in 0..<dataManager.shifts.count {
            var shift = dataManager.shifts[i]
            
            // Check if this looks like an existing record (deviceID is default or empty)
            if shift.deviceID.isEmpty || shift.deviceID == "unknown" {
                // Use shift start date as created date for existing shifts
                shift.createdDate = shift.startDate
                shift.modifiedDate = shift.endDate ?? shift.startDate
                shift.deviceID = deviceID
                shift.isDeleted = false // Ensure not marked as deleted
                
                dataManager.shifts[i] = shift
            }
        }
        
        // Migrate all existing expenses
        for i in 0..<expenseManager.expenses.count {
            var expense = expenseManager.expenses[i]
            
            // Check if this looks like an existing record (deviceID is default or empty)
            if expense.deviceID.isEmpty || expense.deviceID == "unknown" {
                // Use expense date as created date for existing expenses
                expense.createdDate = expense.date
                expense.modifiedDate = expense.date
                expense.deviceID = deviceID
                expense.isDeleted = false // Ensure not marked as deleted
                
                expenseManager.expenses[i] = expense
            }
        }
        
        // Save the migrated data
        dataManager.saveShifts()
        expenseManager.saveExpenses()
    }*/
}

struct BenefitCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
    }
}

struct HowItWorksStep: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text("\(number)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.blue))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

struct InitialSyncProgressView: View {
    @Binding var isVisible: Bool
    let totalShifts: Int
    let totalExpenses: Int
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                
                VStack(spacing: 8) {
                    Text("Performing Initial Sync")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Uploading \(totalShifts) shifts and \(totalExpenses) expenses to iCloud...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("This may take a moment")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(radius: 10)
            )
            .padding(.horizontal, 40)
        }
    }
}

