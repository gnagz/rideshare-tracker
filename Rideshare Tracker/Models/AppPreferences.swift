//
//  AppPreferences.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//

import Foundation

struct BackupPreferences: Codable {
    let tankCapacity: Double
    let gasPrice: Double
    let standardMileageRate: Double
    let weekStartDay: Int
    let dateFormat: String
    let timeFormat: String
    let timeZoneIdentifier: String
}

struct BackupData: Codable {
    let shifts: [RideshareShift]
    let preferences: BackupPreferences
    let exportDate: Date
    let appVersion: String
}

class AppPreferences: ObservableObject {
    @Published var tankCapacity: Double = 14.3
    @Published var gasPrice: Double = 3.50
    @Published var standardMileageRate: Double = 0.70 // 2025 IRS rate
    @Published var weekStartDay: Int = 2 // Monday = 2 (Calendar.Weekday)
    @Published var dateFormat: String = "M/d/yyyy" // Default US format
    @Published var timeFormat: String = "h:mm a" // 12-hour format
    @Published var timeZoneIdentifier: String = TimeZone.current.identifier // Default to device timezone
    
    init() {
        loadPreferences()
    }
    
    private func loadPreferences() {
        tankCapacity = UserDefaults.standard.double(forKey: "tankCapacity")
        if tankCapacity == 0 { tankCapacity = 14.3 }
        
        gasPrice = UserDefaults.standard.double(forKey: "gasPrice")
        if gasPrice == 0 { gasPrice = 3.50 }
        
        standardMileageRate = UserDefaults.standard.double(forKey: "standardMileageRate")
        if standardMileageRate == 0 { standardMileageRate = 0.70 }
        
        weekStartDay = UserDefaults.standard.integer(forKey: "weekStartDay")
        if weekStartDay == 0 { weekStartDay = 2 } // Default to Monday
        
        dateFormat = UserDefaults.standard.string(forKey: "dateFormat") ?? "M/d/yyyy"
        timeFormat = UserDefaults.standard.string(forKey: "timeFormat") ?? "h:mm a"
        timeZoneIdentifier = UserDefaults.standard.string(forKey: "timeZoneIdentifier") ?? TimeZone.current.identifier
    }
    
    func savePreferences() {
        UserDefaults.standard.set(tankCapacity, forKey: "tankCapacity")
        UserDefaults.standard.set(gasPrice, forKey: "gasPrice")
        UserDefaults.standard.set(standardMileageRate, forKey: "standardMileageRate")
        UserDefaults.standard.set(weekStartDay, forKey: "weekStartDay")
        UserDefaults.standard.set(dateFormat, forKey: "dateFormat")
        UserDefaults.standard.set(timeFormat, forKey: "timeFormat")
        UserDefaults.standard.set(timeZoneIdentifier, forKey: "timeZoneIdentifier")
    }
    
    var weekStartDayName: String {
        let formatter = DateFormatter()
        let weekdays = formatter.weekdaySymbols
        return weekdays?[weekStartDay - 1] ?? "Monday"
    }
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current
        return formatter
    }
    
    var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = timeFormat
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current
        return formatter
    }
    
    func formatDate(_ date: Date) -> String {
        return dateFormatter.string(from: date)
    }
    
    func formatTime(_ date: Date) -> String {
        return timeFormatter.string(from: date)
    }
    
    func importPreferences(_ backupPrefs: BackupPreferences) {
        tankCapacity = backupPrefs.tankCapacity
        gasPrice = backupPrefs.gasPrice
        standardMileageRate = backupPrefs.standardMileageRate
        weekStartDay = backupPrefs.weekStartDay
        dateFormat = backupPrefs.dateFormat
        timeFormat = backupPrefs.timeFormat
        timeZoneIdentifier = backupPrefs.timeZoneIdentifier
        savePreferences()
    }
    
    func exportData(shifts: [RideshareShift]) -> URL? {
        let backupPrefs = BackupPreferences(
            tankCapacity: tankCapacity,
            gasPrice: gasPrice,
            standardMileageRate: standardMileageRate,
            weekStartDay: weekStartDay,
            dateFormat: dateFormat,
            timeFormat: timeFormat,
            timeZoneIdentifier: timeZoneIdentifier
        )
        
        let backupData = BackupData(
            shifts: shifts,
            preferences: backupPrefs,
            exportDate: Date(),
            appVersion: "1.0"
        )
        
        guard let jsonData = try? JSONEncoder().encode(backupData) else {
            return nil
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = formatter.string(from: Date())
        let filename = "RideshareTracker_Backup_\(dateString).json"
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        
        do {
            try jsonData.write(to: fileURL)
            return fileURL
        } catch {
            print("Error writing backup file: \(error)")
            return nil
        }
    }
    
    static func importData(from url: URL) -> Result<BackupData, ImportError> {
        do {
            let data = try Data(contentsOf: url)
            let backupData = try JSONDecoder().decode(BackupData.self, from: data)
            return .success(backupData)
        } catch {
            if error is DecodingError {
                return .failure(.invalidFormat)
            } else {
                return .failure(.fileReadError)
            }
        }
    }
}

enum ImportError: LocalizedError {
    case invalidFormat
    case fileReadError
    case duplicateData
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid backup file format"
        case .fileReadError:
            return "Unable to read backup file"
        case .duplicateData:
            return "Some data already exists"
        }
    }
}
