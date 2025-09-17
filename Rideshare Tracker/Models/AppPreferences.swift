//
//  AppPreferences.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/10/25.
//

import Foundation
import UniformTypeIdentifiers

enum DateRangeOption: String, CaseIterable {
    case all = "All"
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This Week"
    case lastWeek = "Last Week"
    case thisMonth = "This Month"
    case lastMonth = "Last Month"
    case thisYear = "This Year"
    case lastYear = "Last Year"
    case custom = "Custom"
    
    func getDateRange(weekStartDay: Int = 1, referenceDate: Date? = nil) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = referenceDate ?? Date()
        
        switch self {
        case .all:
            return (Date.distantPast, Date.distantFuture)
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
            return (startOfDay, endOfDay)
        case .yesterday:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            let startOfDay = calendar.startOfDay(for: yesterday)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? yesterday
            return (startOfDay, endOfDay)
        case .thisWeek:
            return getWeekRange(for: now, weekStartDay: weekStartDay, calendar: calendar)
        case .lastWeek:
            let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
            return getWeekRange(for: lastWeek, weekStartDay: weekStartDay, calendar: calendar)
        case .thisMonth:
            let monthInterval = calendar.dateInterval(of: .month, for: now) ?? DateInterval(start: now, end: now)
            let endOfMonth = calendar.date(byAdding: .day, value: -1, to: monthInterval.end) ?? monthInterval.end
            let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfMonth) ?? endOfMonth
            return (monthInterval.start, endOfDay)
        case .lastMonth:
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            let monthInterval = calendar.dateInterval(of: .month, for: lastMonth) ?? DateInterval(start: lastMonth, end: lastMonth)
            let endOfMonth = calendar.date(byAdding: .day, value: -1, to: monthInterval.end) ?? monthInterval.end
            let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfMonth) ?? endOfMonth
            return (monthInterval.start, endOfDay)
        case .thisYear:
            let yearInterval = calendar.dateInterval(of: .year, for: now) ?? DateInterval(start: now, end: now)
            let endOfYear = calendar.date(byAdding: .day, value: -1, to: yearInterval.end) ?? yearInterval.end
            let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfYear) ?? endOfYear
            return (yearInterval.start, endOfDay)
        case .lastYear:
            let lastYear = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            let yearInterval = calendar.dateInterval(of: .year, for: lastYear) ?? DateInterval(start: lastYear, end: lastYear)
            let endOfYear = calendar.date(byAdding: .day, value: -1, to: yearInterval.end) ?? yearInterval.end
            let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfYear) ?? endOfYear
            return (yearInterval.start, endOfDay)
        case .custom:
            return (now, now) // Will be ignored when custom is selected
        }
    }
    
    private func getWeekRange(for date: Date, weekStartDay: Int, calendar: Calendar) -> (start: Date, end: Date) {
        // weekStartDay: 1 = Monday, 2 = Tuesday, ..., 7 = Sunday
        // Calendar.current uses 1 = Sunday, 2 = Monday, ..., 7 = Saturday
        let calendarWeekStartDay = weekStartDay == 7 ? 1 : weekStartDay + 1
        
        var customCalendar = calendar
        customCalendar.firstWeekday = calendarWeekStartDay
        
        let weekInterval = customCalendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, end: date)
        
        // Fix end date to be end of day instead of start of next day
        let endOfWeek = customCalendar.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.end
        let endOfDay = customCalendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfWeek) ?? endOfWeek
        
        return (weekInterval.start, endOfDay)
    }
}

struct BackupPreferences: Codable {
    let tankCapacity: Double
    let gasPrice: Double
    let standardMileageRate: Double
    let weekStartDay: Int
    let dateFormat: String
    let timeFormat: String
    let timeZoneIdentifier: String
    
    // Tax preferences (optional for backward compatibility)
    let tipDeductionEnabled: Bool?
    let effectivePersonalTaxRate: Double?
    
    // Sync preferences (optional for backward compatibility)
    let incrementalSyncEnabled: Bool?
    let syncFrequency: String?
    let lastIncrementalSyncDate: Date?
}

struct BackupData: Codable {
    let shifts: [RideshareShift]
    let expenses: [ExpenseItem]?
    let preferences: BackupPreferences
    let exportDate: Date
    let appVersion: String
}

struct CSVImportResult {
    let shifts: [RideshareShift]
}

@MainActor
class AppPreferences: ObservableObject {
    static let shared = AppPreferences()
    
    @Published var tankCapacity: Double = 14.3
    @Published var gasPrice: Double = 3.50
    @Published var standardMileageRate: Double = 0.70 // 2025 IRS rate
    @Published var weekStartDay: Int = 2 // Monday = 2 (Calendar.Weekday)
    @Published var dateFormat: String = "M/d/yyyy" // Default US format
    @Published var timeFormat: String = "h:mm a" // 12-hour format
    @Published var timeZoneIdentifier: String = TimeZone.current.identifier // Default to device timezone
    
    // Tax Calculation Preferences
    @Published var tipDeductionEnabled: Bool = true // Tips deductible through tax year 2028
    @Published var effectivePersonalTaxRate: Double = 22.0 // Combined federal + state tax rate percentage
    
    // Incremental Sync Settings
    @Published var incrementalSyncEnabled: Bool = false
    @Published var syncFrequency: String = "Immediate"
    @Published var lastIncrementalSyncDate: Date?
    
    private init() {
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
        
        // Load tax calculation preferences
        tipDeductionEnabled = UserDefaults.standard.object(forKey: "tipDeductionEnabled") != nil ? UserDefaults.standard.bool(forKey: "tipDeductionEnabled") : true
        effectivePersonalTaxRate = UserDefaults.standard.double(forKey: "effectivePersonalTaxRate")
        if effectivePersonalTaxRate == 0 { effectivePersonalTaxRate = 22.0 }
        
        // Load incremental sync settings
        incrementalSyncEnabled = UserDefaults.standard.bool(forKey: "incrementalSyncEnabled")
        syncFrequency = UserDefaults.standard.string(forKey: "syncFrequency") ?? "Immediate"
        if let syncDateData = UserDefaults.standard.data(forKey: "lastIncrementalSyncDate") {
            lastIncrementalSyncDate = try? JSONDecoder().decode(Date.self, from: syncDateData)
        }
    }
    
    func savePreferences() {
        UserDefaults.standard.set(tankCapacity, forKey: "tankCapacity")
        UserDefaults.standard.set(gasPrice, forKey: "gasPrice")
        UserDefaults.standard.set(standardMileageRate, forKey: "standardMileageRate")
        UserDefaults.standard.set(weekStartDay, forKey: "weekStartDay")
        UserDefaults.standard.set(dateFormat, forKey: "dateFormat")
        UserDefaults.standard.set(timeFormat, forKey: "timeFormat")
        UserDefaults.standard.set(timeZoneIdentifier, forKey: "timeZoneIdentifier")
        
        // Save tax calculation preferences
        UserDefaults.standard.set(tipDeductionEnabled, forKey: "tipDeductionEnabled")
        UserDefaults.standard.set(effectivePersonalTaxRate, forKey: "effectivePersonalTaxRate")
        
        // Save incremental sync settings
        UserDefaults.standard.set(incrementalSyncEnabled, forKey: "incrementalSyncEnabled")
        UserDefaults.standard.set(syncFrequency, forKey: "syncFrequency")
        if let lastSync = lastIncrementalSyncDate,
           let syncDateData = try? JSONEncoder().encode(lastSync) {
            UserDefaults.standard.set(syncDateData, forKey: "lastIncrementalSyncDate")
        }
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
        
        // Import tax preferences if available (backward compatibility)
        if let tipEnabled = backupPrefs.tipDeductionEnabled {
            tipDeductionEnabled = tipEnabled
        }
        if let taxRate = backupPrefs.effectivePersonalTaxRate {
            effectivePersonalTaxRate = taxRate
        }
        
        // Import sync preferences if available (backward compatibility)
        if let syncEnabled = backupPrefs.incrementalSyncEnabled {
            incrementalSyncEnabled = syncEnabled
        }
        if let syncFreq = backupPrefs.syncFrequency {
            syncFrequency = syncFreq
        }
        if let syncDate = backupPrefs.lastIncrementalSyncDate {
            lastIncrementalSyncDate = syncDate
        }
        
        savePreferences()
    }
    
    func exportData(shifts: [RideshareShift], expenses: [ExpenseItem] = []) -> URL? {
        let backupPrefs = BackupPreferences(
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
        
        let backupData = BackupData(
            shifts: shifts,
            expenses: expenses.isEmpty ? nil : expenses,
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
        let filename = "RideshareTracker_Backup_at_\(dateString).json"
        
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
    
    // MARK: - CSV Export/Import Functions
    
    
    func exportExpensesCSV(expenses: [ExpenseItem], fromDate: Date, toDate: Date) -> URL? {
        // Filter expenses by date range and exclude deleted expenses
        let filteredExpenses = expenses.filter { expense in
            !expense.isDeleted &&
            Calendar.current.startOfDay(for: expense.date) >= Calendar.current.startOfDay(for: fromDate) &&
            Calendar.current.startOfDay(for: expense.date) <= Calendar.current.startOfDay(for: toDate)
        }.sorted { $0.date < $1.date }
        
        // CSV Headers
        let headers = [
            "Date", "Category", "Description", "Amount"
        ]
        
        var csvContent = headers.joined(separator: ",") + "\n"
        
        // Add data rows
        for expense in filteredExpenses {
            let row = [
                formatDate(expense.date),
                expense.category.rawValue,
                expense.description,
                String(format: "%.2f", expense.amount)
            ]
            
            // Escape commas and quotes in CSV values
            let escapedRow = row.map { value in
                if value.contains(",") || value.contains("\"") {
                    return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
                }
                return value
            }
            
            csvContent += escapedRow.joined(separator: ",") + "\n"
        }
        
        // Create file
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fromDateString = dateFormatter.string(from: fromDate)
        let toDateString = dateFormatter.string(from: toDate)
        
        let timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = timestampFormatter.string(from: Date())
        
        let filename = "RideshareTracker_Expenses_\(fromDateString)_to_\(toDateString)_at_\(timestamp).csv"
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        
        do {
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error writing CSV file: \(error)")
            return nil
        }
    }
    
    private func tankLevelToString(_ level: Double) -> String {
        switch level {
        case 0.0: return "E"
        case 1.0: return "1/8"
        case 2.0: return "1/4"
        case 3.0: return "3/8"
        case 4.0: return "1/2"
        case 5.0: return "5/8"
        case 6.0: return "3/4"
        case 7.0: return "7/8"
        case 8.0: return "F"
        default: return String(level)
        }
    }
    
    private func tankLevelToDecimal(_ level: Double) -> Double {
        // Convert internal 0-8 scale to 0-1 decimal scale
        return level / 8.0
    }
    
    private func tankLevelFromString(_ str: String) -> Double {
        switch str.uppercased() {
        case "E": return 0.0
        case "1/8": return 1.0
        case "1/4": return 2.0
        case "3/8": return 3.0
        case "1/2": return 4.0
        case "5/8": return 5.0
        case "3/4": return 6.0
        case "7/8": return 7.0
        case "F": return 8.0
        default: 
            // Handle decimal values from CSV (0.0 to 1.0)
            if let decimal = Double(str) {
                if decimal <= 1.0 {
                    // Convert from 0-1 scale to 0-8 scale and round to nearest 1/8
                    let scaledValue = decimal * 8.0
                    return round(scaledValue)
                }
            }
            return Double(str) ?? 0.0
        }
    }
    
    static func importCSV(from url: URL) -> Result<CSVImportResult, ImportError> {
        debugPrint("Starting CSV import from: \(url.lastPathComponent)")
        
        do {
            let csvContent = try String(contentsOf: url, encoding: .utf8)
            let lines = csvContent.components(separatedBy: .newlines).filter { !$0.isEmpty }
            debugPrint("CSV file loaded: \(lines.count) non-empty lines found")
            
            guard lines.count > 1 else {
                debugPrint("ERROR: CSV file has insufficient data (\(lines.count) lines)")
                return .failure(.invalidFormat)
            }
            
            let headers = parseCSVLine(lines[0])
            debugPrint("CSV headers parsed: \(headers.count) columns - [\(headers.joined(separator: ", "))]")
            
            var shifts: [RideshareShift] = []
            debugPrint("Processing \(lines.count - 1) data rows...")
            
            // Create a DateFormatter for parsing
            let dateFormatter = DateFormatter()
            let timeFormatter = DateFormatter()
            
            for i in 1..<lines.count {
                let values = parseCSVLine(lines[i])
                debugPrint("Row \(i): Parsed \(values.count) values")
                
                guard values.count >= headers.count else { 
                    debugPrint("SKIP Row \(i): Insufficient columns (\(values.count) < \(headers.count))")
                    continue 
                }
                
                var shift = RideshareShift(
                    startDate: Date(),
                    startMileage: 0,
                    startTankReading: 0,
                    hasFullTankAtStart: false
                )
                
                // Define which columns to import (data entry fields only, preferences are optional)
                let dataFieldsToImport: Set<String> = [
                    "StartDate", "StartTime", "EndDate", "EndTime",
                    "StartMileage", "EndMileage", 
                    "StartTankReading", "EndTankReading", "HasFullTankAtStart", "DidRefuelAtEnd",
                    "RefuelGallons", "RefuelCost",
                    "TotalTrips", "Trips", "NetFare", "Tips", "Promotions", "RiderFees",
                    "TotalTolls", "Tolls", "TollsReimbursed", "ParkingFees", "MiscFees",
                    "GasPrice", "StandardMileageRate"
                ]
                
                // Map CSV values to shift properties (only import known data fields)
                var processedFields = 0
                for (index, header) in headers.enumerated() {
                    guard index < values.count else { continue }
                    let value = values[index].trimmingCharacters(in: .whitespaces)
                    
                    // Only process known data fields
                    if dataFieldsToImport.contains(header) {
                        processedFields += 1
                        switch header {
                    case "StartDate":
                        if let date = parseDateFromCSV(value, formatter: dateFormatter) {
                            debugPrint("Row \(i): StartDate parsed '\(value)' -> \(date)")
                            // We'll combine with start time later
                            let calendar = Calendar.current
                            let components = calendar.dateComponents([.year, .month, .day], from: date)
                            if let baseDate = calendar.date(from: components) {
                                shift.startDate = baseDate
                            }
                        } else {
                            debugPrint("WARNING Row \(i): Failed to parse StartDate '\(value)'")
                        }
                    case "StartTime":
                        if let time = parseTimeFromCSV(value, formatter: timeFormatter) {
                            debugPrint("Row \(i): StartTime parsed '\(value)' -> \(time)")
                            let calendar = Calendar.current
                            let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
                            let dateComponents = calendar.dateComponents([.year, .month, .day], from: shift.startDate)
                            var fullComponents = DateComponents()
                            fullComponents.year = dateComponents.year
                            fullComponents.month = dateComponents.month
                            fullComponents.day = dateComponents.day
                            fullComponents.hour = timeComponents.hour
                            fullComponents.minute = timeComponents.minute
                            if let fullDate = calendar.date(from: fullComponents) {
                                shift.startDate = fullDate
                                debugPrint("Row \(i): Combined StartDate+Time -> \(fullDate)")
                            }
                        } else {
                            debugPrint("WARNING Row \(i): Failed to parse StartTime '\(value)'")
                        }
                    case "EndDate":
                        if !value.isEmpty, let date = parseDateFromCSV(value, formatter: dateFormatter) {
                            let calendar = Calendar.current
                            let components = calendar.dateComponents([.year, .month, .day], from: date)
                            if let baseDate = calendar.date(from: components) {
                                shift.endDate = baseDate
                            }
                        }
                    case "EndTime":
                        if !value.isEmpty, let time = parseTimeFromCSV(value, formatter: timeFormatter), let endDate = shift.endDate {
                            let calendar = Calendar.current
                            let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
                            let dateComponents = calendar.dateComponents([.year, .month, .day], from: endDate)
                            var fullComponents = DateComponents()
                            fullComponents.year = dateComponents.year
                            fullComponents.month = dateComponents.month
                            fullComponents.day = dateComponents.day
                            fullComponents.hour = timeComponents.hour
                            fullComponents.minute = timeComponents.minute
                            if let fullDate = calendar.date(from: fullComponents) {
                                shift.endDate = fullDate
                            }
                        }
                    case "StartMileage":
                        shift.startMileage = Double(value) ?? 0
                    case "EndMileage":
                        if !value.isEmpty {
                            shift.endMileage = Double(value)
                        }
                    case "StartTankReading":
                        let tankLevel = AppPreferences().tankLevelFromString(value)
                        shift.startTankReading = tankLevel
                        debugPrint("Row \(i): StartTankReading '\(value)' -> \(tankLevel)/8")
                    case "EndTankReading":
                        if !value.isEmpty {
                            let tankLevel = AppPreferences().tankLevelFromString(value)
                            shift.endTankReading = tankLevel
                            debugPrint("Row \(i): EndTankReading '\(value)' -> \(tankLevel)/8")
                        }
                    case "HasFullTankAtStart":
                        shift.hasFullTankAtStart = value.uppercased() == "YES" || value == "1" || value.uppercased() == "TRUE"
                    case "DidRefuelAtEnd":
                        if !value.isEmpty {
                            shift.didRefuelAtEnd = value.uppercased() == "YES" || value == "1" || value.uppercased() == "TRUE"
                        }
                    case "RefuelGallons":
                        if !value.isEmpty {
                            shift.refuelGallons = Double(value)
                        }
                    case "RefuelCost":
                        if !value.isEmpty {
                            shift.refuelCost = Double(value)
                        }
                    case "TotalTrips", "Trips":
                        if !value.isEmpty {
                            shift.trips = Int(value)
                        }
                    case "NetFare":
                        if !value.isEmpty {
                            shift.netFare = Double(value)
                        }
                    case "Tips":
                        if !value.isEmpty {
                            shift.tips = Double(value)
                        }
                    case "Promotions":
                        if !value.isEmpty {
                            shift.promotions = Double(value)
                        }
                    case "TotalTolls", "Tolls":
                        if !value.isEmpty {
                            shift.tolls = Double(value)
                        }
                    case "TollsReimbursed":
                        if !value.isEmpty {
                            shift.tollsReimbursed = Double(value)
                        }
                    case "ParkingFees":
                        if !value.isEmpty {
                            shift.parkingFees = Double(value)
                        }
                    case "MiscFees":
                        if !value.isEmpty {
                            shift.miscFees = Double(value)
                        }
                    case "GasPrice":
                        if !value.isEmpty {
                            shift.gasPrice = Double(value)
                        }
                    case "StandardMileageRate":
                        if !value.isEmpty {
                            shift.standardMileageRate = Double(value)
                        }
                    default:
                        break
                        }
                    } else {
                        debugPrint("Row \(i): Skipping unknown field '\(header)' = '\(value)'")
                    }
                }
                debugPrint("Row \(i): Processed \(processedFields) known fields, creating shift")
                
                shifts.append(shift)
            }
            
            debugPrint("CSV import completed: \(shifts.count) shifts created successfully")
            return .success(CSVImportResult(shifts: shifts))
            
        } catch {
            debugPrint("ERROR: CSV import failed with error: \(error.localizedDescription)")
            return .failure(.fileReadError)
        }
    }
    
    private static func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var currentField = ""
        var inQuotes = false
        var i = line.startIndex
        
        while i < line.endIndex {
            let char = line[i]
            
            if char == "\"" {
                if inQuotes && line.index(after: i) < line.endIndex && line[line.index(after: i)] == "\"" {
                    // Escaped quote
                    currentField += "\""
                    i = line.index(after: i)
                } else {
                    // Toggle quote state
                    inQuotes.toggle()
                }
            } else if char == "," && !inQuotes {
                // Field separator
                result.append(currentField)
                currentField = ""
            } else {
                currentField += String(char)
            }
            
            i = line.index(after: i)
        }
        
        result.append(currentField)
        return result
    }
    
    private static func parseDateFromCSV(_ dateString: String, formatter: DateFormatter) -> Date? {
        debugPrint("Attempting to parse date: '\(dateString)'")
        
        // Try common date formats, including two-digit years
        let formats = [
            "M/d/yy", "MM/dd/yy", "d/M/yy", "dd/MM/yy",  // Two-digit year formats (most common)
            "M/d/yyyy", "MM/dd/yyyy", "d/M/yyyy", "dd/MM/yyyy",  // Four-digit year formats
            "yyyy-MM-dd", "MMM d, yyyy", "dd-MM-yyyy", "yyyy/MM/dd"  // Other common formats
        ]
        
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                debugPrint("Date '\(dateString)' parsed successfully with format '\(format)' -> \(date)")
                return date
            }
        }
        debugPrint("Failed to parse date '\(dateString)' with any known format")
        return nil
    }
    
    private static func parseTimeFromCSV(_ timeString: String, formatter: DateFormatter) -> Date? {
        debugPrint("Attempting to parse time: '\(timeString)'")
        
        // Try common time formats
        let formats = ["h:mm a", "HH:mm", "h:mm:ss a", "HH:mm:ss"]
        
        for format in formats {
            formatter.dateFormat = format
            if let time = formatter.date(from: timeString) {
                debugPrint("Time '\(timeString)' parsed successfully with format '\(format)' -> \(time)")
                return time
            }
        }
        debugPrint("Failed to parse time '\(timeString)' with any known format")
        return nil
    }
    
    // MARK: - Export functions with range-aware naming
    
    func exportCSVWithRange(shifts: [RideshareShift], selectedRange: DateRangeOption, fromDate: Date, toDate: Date) -> URL? {
        // Filter shifts by date range and exclude deleted shifts
        let filteredShifts = shifts.filter { shift in
            !shift.isDeleted && shift.startDate >= fromDate && shift.startDate <= toDate
        }
        
        // Generate CSV content with all input fields and calculated fields
        let headers = [
            // Input fields for editing/import
            "StartDate", "StartTime", "EndDate", "EndTime",
            "StartMileage", "EndMileage", "StartTankReading", "EndTankReading", 
            "RefuelGallons", "RefuelCost",
            "Trips", "NetFare", "Tips", "Promotions", "RiderFees",
            "Tolls", "TollsReimbursed", "ParkingFees", "MiscFees",
            // Calculated fields for reporting/analysis
            "C_Duration", "C_ShiftMileage", "C_Revenue", "C_GasCost", "C_GasUsage", "C_MPG",
            "C_TotalTips", "C_TaxableIncome", "C_DeductibleExpenses",
            "C_ExpectedPayout", "C_OutOfPocketCosts", "C_CashFlowProfit", "C_ProfitPerHour",
            // Preference fields for context
            "P_TankCapacity", "P_GasPrice", "P_StandardMileageRate"
        ]
        
        var csvContent = headers.joined(separator: ",") + "\n"
        
        for shift in filteredShifts.sorted(by: { $0.startDate < $1.startDate }) {
            let row = [
                // Input fields for editing/import
                formatDate(shift.startDate),
                formatTime(shift.startDate),
                shift.endDate != nil ? formatDate(shift.endDate!) : "",
                shift.endDate != nil ? formatTime(shift.endDate!) : "",
                String(shift.startMileage),
                shift.endMileage != nil ? String(shift.endMileage!) : "",
                String(format: "%.3f", tankLevelToDecimal(shift.startTankReading)),
                shift.endTankReading != nil ? String(format: "%.3f", tankLevelToDecimal(shift.endTankReading!)) : "",
                shift.refuelGallons != nil ? String(shift.refuelGallons!) : "",
                shift.refuelCost != nil ? String(format: "%.2f", shift.refuelCost!) : "",
                shift.trips != nil ? String(shift.trips!) : "",
                shift.netFare != nil ? String(format: "%.2f", shift.netFare!) : "",
                shift.tips != nil ? String(format: "%.2f", shift.tips!) : "",
                shift.promotions != nil ? String(format: "%.2f", shift.promotions!) : "",
                shift.tolls != nil ? String(format: "%.2f", shift.tolls!) : "",
                shift.tollsReimbursed != nil ? String(format: "%.2f", shift.tollsReimbursed!) : "",
                shift.parkingFees != nil ? String(format: "%.2f", shift.parkingFees!) : "",
                shift.miscFees != nil ? String(format: "%.2f", shift.miscFees!) : "",
                // Calculated fields for reporting/analysis
                shift.endDate != nil ? String(format: "%.1f", shift.shiftDuration / 3600.0) : "",
                String(format: "%.1f", shift.shiftMileage),
                String(format: "%.2f", shift.revenue),
                String(format: "%.2f", shift.shiftGasCost(tankCapacity: tankCapacity, gasPrice: gasPrice)),
                String(format: "%.2f", shift.shiftGasUsage(tankCapacity: tankCapacity)),
                String(format: "%.1f", shift.shiftMPG(tankCapacity: tankCapacity)),
                String(format: "%.2f", shift.totalTips),
                String(format: "%.2f", shift.taxableIncome),
                String(format: "%.2f", shift.deductibleExpenses(mileageRate: standardMileageRate)),
                String(format: "%.2f", shift.expectedPayout),
                String(format: "%.2f", shift.outOfPocketCosts(tankCapacity: tankCapacity, gasPrice: gasPrice)),
                String(format: "%.2f", shift.cashFlowProfit(tankCapacity: tankCapacity, gasPrice: gasPrice)),
                String(format: "%.2f", shift.profitPerHour(tankCapacity: tankCapacity, gasPrice: gasPrice)),
                // Preference fields for context
                String(tankCapacity),
                String(format: "%.3f", shift.gasPrice ?? gasPrice),
                String(format: "%.3f", shift.standardMileageRate ?? standardMileageRate)
            ]
            
            let escapedRow = row.map { field in
                if field.contains(",") || field.contains("\"") || field.contains("\n") {
                    return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
                }
                return field
            }
            
            csvContent += escapedRow.joined(separator: ",") + "\n"
        }
        
        // Create filename based on range
        let timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = timestampFormatter.string(from: Date())
        
        let filename: String
        if selectedRange == .all {
            filename = "RideshareTracker_Shifts_at_\(timestamp).csv"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let fromDateString = dateFormatter.string(from: fromDate)
            let toDateString = dateFormatter.string(from: toDate)
            filename = "RideshareTracker_Shifts_\(fromDateString)_to_\(toDateString)_at_\(timestamp).csv"
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        
        do {
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error writing CSV file: \(error)")
            return nil
        }
    }
    
    func exportExpensesCSVWithRange(expenses: [ExpenseItem], selectedRange: DateRangeOption, fromDate: Date, toDate: Date) -> URL? {
        // Filter expenses first
        let filteredExpenses = expenses.filter { expense in
            expense.date >= fromDate && expense.date <= toDate
        }
        
        // Generate CSV content
        var csvContent = "Date,Category,Description,Amount\n"
        
        for expense in filteredExpenses.sorted(by: { $0.date < $1.date }) {
            let row = [
                formatDate(expense.date),
                expense.category.rawValue,
                expense.description,
                String(format: "%.2f", expense.amount)
            ]
            
            let escapedRow = row.map { field in
                if field.contains(",") || field.contains("\"") || field.contains("\n") {
                    return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
                }
                return field
            }
            
            csvContent += escapedRow.joined(separator: ",") + "\n"
        }
        
        // Create filename based on range
        let timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = timestampFormatter.string(from: Date())
        
        let filename: String
        if selectedRange == .all {
            filename = "RideshareTracker_Expenses_at_\(timestamp).csv"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let fromDateString = dateFormatter.string(from: fromDate)
            let toDateString = dateFormatter.string(from: toDate)
            filename = "RideshareTracker_Expenses_\(fromDateString)_to_\(toDateString)_at_\(timestamp).csv"
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        
        do {
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error writing CSV file: \(error)")
            return nil
        }
    }
    
    func exportDataWithRange(shifts: [RideshareShift], expenses: [ExpenseItem], selectedRange: DateRangeOption, fromDate: Date, toDate: Date) -> URL? {
        let backupData = BackupData(
            shifts: shifts,
            expenses: expenses,
            preferences: BackupPreferences(
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
            ),
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        )
        
        guard let jsonData = try? JSONEncoder().encode(backupData) else {
            return nil
        }
        
        // Create filename based on range
        let timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = timestampFormatter.string(from: Date())
        
        let filename: String
        if selectedRange == .all {
            filename = "RideshareTracker_Backup_at_\(timestamp).json"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let fromDateString = dateFormatter.string(from: fromDate)
            let toDateString = dateFormatter.string(from: toDate)
            filename = "RideshareTracker_Backup_\(fromDateString)_to_\(toDateString)_at_\(timestamp).json"
        }
        
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
    
    func createFullBackup(shifts: [RideshareShift], expenses: [ExpenseItem]) -> URL? {
        let backupData = BackupData(
            shifts: shifts,
            expenses: expenses,
            preferences: BackupPreferences(
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
            ),
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        )
        
        guard let jsonData = try? JSONEncoder().encode(backupData) else {
            return nil
        }
        
        // Simple filename for full backups
        let timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = timestampFormatter.string(from: Date())
        let filename = "RideshareTracker_Backup_\(timestamp).json"
        
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
