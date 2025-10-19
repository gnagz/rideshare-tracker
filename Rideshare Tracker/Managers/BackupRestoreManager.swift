//
//  BackupRestoreManager.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 10/18/25.
//  Extracted from AppPreferences.swift
//

import Foundation
import SwiftUI

// MARK: - Backup/Restore Error Types

enum BackupRestoreError: LocalizedError {
    case invalidFormat
    case fileReadError
    case fileWriteError
    case encodingFailed(Error)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid backup file format"
        case .fileReadError:
            return "Unable to read backup file"
        case .fileWriteError:
            return "Unable to write backup file"
        case .encodingFailed(let error):
            return "Failed to encode backup data: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode backup data: \(error.localizedDescription)"
        }
    }
}

// MARK: - Backup/Restore Manager

@MainActor
class BackupRestoreManager: ObservableObject {
    static let shared = BackupRestoreManager()

    @Published var lastError: BackupRestoreError?

    private init() {}

    // MARK: - Restore from Backup (Full Orchestration)

    func restoreFromBackup(backupData: BackupData, shiftManager: ShiftDataManager, expenseManager: ExpenseDataManager, preferencesManager: PreferencesManager) {
        // Clear existing data
        shiftManager.shifts.removeAll()
        expenseManager.expenses.removeAll()

        // Restore shifts
        for shift in backupData.shifts {
            shiftManager.addShift(shift)
        }

        // Restore expenses
        if let expenses = backupData.expenses {
            for expense in expenses {
                expenseManager.addExpense(expense)
            }
        }

        // Restore preferences
        preferencesManager.restorePreferences(backupData.preferences)

        debugMessage("Full restore completed: \(backupData.shifts.count) shifts, \(backupData.expenses?.count ?? 0) expenses")
    }

    // MARK: - Create Backup (JSON)

    func createFullBackup(shifts: [RideshareShift], expenses: [ExpenseItem], preferences: AppPreferences) throws(BackupRestoreError) -> URL {
        lastError = nil
    
        let backupData = BackupData(
            shifts: shifts,
            expenses: expenses,
            preferences: BackupPreferences(
                tankCapacity: preferences.tankCapacity,
                gasPrice: preferences.gasPrice,
                standardMileageRate: preferences.standardMileageRate,
                weekStartDay: preferences.weekStartDay,
                dateFormat: preferences.dateFormat,
                timeFormat: preferences.timeFormat,
                timeZoneIdentifier: preferences.timeZoneIdentifier,
                tipDeductionEnabled: preferences.tipDeductionEnabled,
                effectivePersonalTaxRate: preferences.effectivePersonalTaxRate,
                incrementalSyncEnabled: preferences.incrementalSyncEnabled,
                syncFrequency: preferences.syncFrequency,
                lastIncrementalSyncDate: preferences.lastIncrementalSyncDate
            ),
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        )

        do {
            let jsonData = try JSONEncoder().encode(backupData)

            // Simple filename for full backups
            let timestampFormatter = DateFormatter()
            timestampFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let timestamp = timestampFormatter.string(from: Date())
            let filename = "RideshareTracker_Backup_\(timestamp).json"

            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(filename)

            try jsonData.write(to: fileURL)
            return fileURL
        } catch let error as EncodingError {
            debugMessage("Error encoding backup data: \(error)")
            lastError = .encodingFailed(error)
            throw .encodingFailed(error)
            // Error handling: Set lastError for UI observation, then throw for caller to handle explicitly
        } catch {
            debugMessage("Error writing backup file: \(error)")
            lastError = .fileWriteError
            throw .fileWriteError
            // Error handling: Set lastError for UI observation, then throw for caller to handle explicitly
        }
    }

    // MARK: - Load Backup (JSON)

    func loadBackup(from url: URL) throws(BackupRestoreError) -> BackupData {
        lastError = nil
        debugMessage("Starting backup restore from: \(url.lastPathComponent)")

        // Handle security-scoped URLs from document picker
        let hasAccess = url.startAccessingSecurityScopedResource()
        debugMessage("Security-scoped URL access: \(hasAccess)")

        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
                debugMessage("Released security-scoped URL access")
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let backupData = try JSONDecoder().decode(BackupData.self, from: data)
            debugMessage("Backup restore completed successfully")
            return backupData
        } catch let error as DecodingError {
            debugMessage("ERROR: Backup decoding failed: \(error.localizedDescription)")
            lastError = .decodingFailed(error)
            throw .decodingFailed(error)
            // Error handling: Set lastError for UI observation, then throw for caller to handle explicitly
        } catch {
            debugMessage("ERROR: Backup file read failed: \(error.localizedDescription)")
            lastError = .fileReadError
            throw .fileReadError
            // Error handling: Set lastError for UI observation, then throw for caller to handle explicitly
        }
    }
}
