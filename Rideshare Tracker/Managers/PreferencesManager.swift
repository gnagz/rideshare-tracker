//
//  PreferencesManager.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 10/18/25.
//  Extracted from AppPreferences.swift
//

import Foundation
import SwiftUI

// MARK: - Preferences Error Types

enum PreferencesError: LocalizedError {
    case loadFailed(Error)
    case saveFailed(Error)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .loadFailed(let error):
            return "Failed to load preferences: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save preferences: \(error.localizedDescription)"
        case .invalidData:
            return "Invalid preferences data"
        }
    }
}

// MARK: - Preferences Manager

@MainActor
class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()

    @Published var lastError: PreferencesError?
    @Published var preferences: AppPreferences

    private init() {
        // Initialize with default values, will be overwritten by loadPreferences()
        preferences = AppPreferences(
            tankCapacity: 14.3, // Default tank capacity in gallons
            gasPrice: 3.50, // Default gas price per gallon
            standardMileageRate: 0.70, // 2025 IRS standard mileage rate
            weekStartDay: 2, // Monday = 2 (Calendar.Weekday)
            dateFormat: "M/d/yyyy", // Default US date format
            timeFormat: "h:mm a", // 12-hour time format
            timeZoneIdentifier: TimeZone.current.identifier, // Default to device timezone
            tipDeductionEnabled: true, // Tips deductible through tax year 2028
            effectivePersonalTaxRate: 22.0, // Combined federal + state tax rate percentage
            incrementalSyncEnabled: false, // Sync disabled by default
            syncFrequency: "Immediate", // Default sync frequency
            lastIncrementalSyncDate: nil
        )
        loadPreferences()
    }

    // MARK: - Load Preferences
    // ⚠️ When adding new AppPreferences properties, add UserDefaults loading here.
    // See AppPreferences struct for full list of locations to update.
    func loadPreferences() {
        var tankCapacity = UserDefaults.standard.double(forKey: "tankCapacity")
        if tankCapacity == 0 { tankCapacity = 14.3 } // Default tank capacity in gallons

        var gasPrice = UserDefaults.standard.double(forKey: "gasPrice")
        if gasPrice == 0 { gasPrice = 3.50 } // Default gas price per gallon

        var standardMileageRate = UserDefaults.standard.double(forKey: "standardMileageRate")
        if standardMileageRate == 0 { standardMileageRate = 0.70 } // 2025 IRS standard mileage rate

        var weekStartDay = UserDefaults.standard.integer(forKey: "weekStartDay")
        if weekStartDay == 0 { weekStartDay = 2 } // Default to Monday (Calendar.Weekday)

        let dateFormat = UserDefaults.standard.string(forKey: "dateFormat") ?? "M/d/yyyy" // Default US date format
        let timeFormat = UserDefaults.standard.string(forKey: "timeFormat") ?? "h:mm a" // 12-hour time format
        let timeZoneIdentifier = UserDefaults.standard.string(forKey: "timeZoneIdentifier") ?? TimeZone.current.identifier // Default to device timezone

        // Load tax calculation preferences
        let tipDeductionEnabled = UserDefaults.standard.object(forKey: "tipDeductionEnabled") != nil ? UserDefaults.standard.bool(forKey: "tipDeductionEnabled") : true // Tips deductible through tax year 2028
        var effectivePersonalTaxRate = UserDefaults.standard.double(forKey: "effectivePersonalTaxRate")
        if effectivePersonalTaxRate == 0 { effectivePersonalTaxRate = 22.0 } // Combined federal + state tax rate percentage

        // Load incremental sync settings
        let incrementalSyncEnabled = UserDefaults.standard.bool(forKey: "incrementalSyncEnabled") // Sync disabled by default
        let syncFrequency = UserDefaults.standard.string(forKey: "syncFrequency") ?? "Immediate" // Default sync frequency
        var lastIncrementalSyncDate: Date? = nil
        if let syncDateData = UserDefaults.standard.data(forKey: "lastIncrementalSyncDate") {
            lastIncrementalSyncDate = try? JSONDecoder().decode(Date.self, from: syncDateData)
        }

        preferences = AppPreferences(
            tankCapacity: tankCapacity,
            gasPrice: gasPrice,
            standardMileageRate: standardMileageRate,
            weekStartDay: weekStartDay,
            dateFormat: dateFormat,
            timeFormat: timeFormat,
            timeZoneIdentifier: timeZoneIdentifier,
            tipDeductionEnabled: tipDeductionEnabled,
            effectivePersonalTaxRate: effectivePersonalTaxRate,
            incrementalSyncEnabled: incrementalSyncEnabled,
            syncFrequency: syncFrequency,
            lastIncrementalSyncDate: lastIncrementalSyncDate
        )
    }

    // MARK: - Save Preferences
    // ⚠️ When adding new AppPreferences properties, add UserDefaults saving here.
    // See AppPreferences struct for full list of locations to update.
    func savePreferences() {
        UserDefaults.standard.set(preferences.tankCapacity, forKey: "tankCapacity")
        UserDefaults.standard.set(preferences.gasPrice, forKey: "gasPrice")
        UserDefaults.standard.set(preferences.standardMileageRate, forKey: "standardMileageRate")
        UserDefaults.standard.set(preferences.weekStartDay, forKey: "weekStartDay")
        UserDefaults.standard.set(preferences.dateFormat, forKey: "dateFormat")
        UserDefaults.standard.set(preferences.timeFormat, forKey: "timeFormat")
        UserDefaults.standard.set(preferences.timeZoneIdentifier, forKey: "timeZoneIdentifier")

        // Save tax calculation preferences
        UserDefaults.standard.set(preferences.tipDeductionEnabled, forKey: "tipDeductionEnabled")
        UserDefaults.standard.set(preferences.effectivePersonalTaxRate, forKey: "effectivePersonalTaxRate")

        // Save incremental sync settings
        UserDefaults.standard.set(preferences.incrementalSyncEnabled, forKey: "incrementalSyncEnabled")
        UserDefaults.standard.set(preferences.syncFrequency, forKey: "syncFrequency")
        if let lastSync = preferences.lastIncrementalSyncDate,
           let syncDateData = try? JSONEncoder().encode(lastSync) {
            UserDefaults.standard.set(syncDateData, forKey: "lastIncrementalSyncDate")
        }
    }

    // MARK: - Restore Preferences from Backup
    // ⚠️ When adding new AppPreferences properties, add restoration from BackupPreferences here.
    // See AppPreferences struct for full list of locations to update.
    func restorePreferences(_ backupPrefs: BackupPreferences) {
        preferences = AppPreferences(
            tankCapacity: backupPrefs.tankCapacity,
            gasPrice: backupPrefs.gasPrice,
            standardMileageRate: backupPrefs.standardMileageRate,
            weekStartDay: backupPrefs.weekStartDay,
            dateFormat: backupPrefs.dateFormat,
            timeFormat: backupPrefs.timeFormat,
            timeZoneIdentifier: backupPrefs.timeZoneIdentifier,
            tipDeductionEnabled: backupPrefs.tipDeductionEnabled ?? preferences.tipDeductionEnabled, // Backward compatibility
            effectivePersonalTaxRate: backupPrefs.effectivePersonalTaxRate ?? preferences.effectivePersonalTaxRate, // Backward compatibility
            incrementalSyncEnabled: backupPrefs.incrementalSyncEnabled ?? preferences.incrementalSyncEnabled, // Backward compatibility
            syncFrequency: backupPrefs.syncFrequency ?? preferences.syncFrequency, // Backward compatibility
            lastIncrementalSyncDate: backupPrefs.lastIncrementalSyncDate ?? preferences.lastIncrementalSyncDate // Backward compatibility
        )

        savePreferences()
    }

    // MARK: - Formatting Helpers

    var weekStartDayName: String {
        let formatter = DateFormatter()
        let weekdays = formatter.weekdaySymbols
        return weekdays?[preferences.weekStartDay - 1] ?? "Monday"
    }

    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = preferences.dateFormat
        formatter.timeZone = TimeZone(identifier: preferences.timeZoneIdentifier) ?? TimeZone.current
        return formatter
    }

    var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = preferences.timeFormat
        formatter.timeZone = TimeZone(identifier: preferences.timeZoneIdentifier) ?? TimeZone.current
        return formatter
    }

    func formatDate(_ date: Date) -> String {
        return dateFormatter.string(from: date)
    }

    func formatTime(_ date: Date) -> String {
        return timeFormatter.string(from: date)
    }
}
