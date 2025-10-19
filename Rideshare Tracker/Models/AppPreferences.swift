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


// MARK: - AppPreferences Model (Data Structure Only)

struct AppPreferences {
    var tankCapacity: Double
    var gasPrice: Double
    var standardMileageRate: Double
    var weekStartDay: Int
    var dateFormat: String
    var timeFormat: String
    var timeZoneIdentifier: String

    // Tax Calculation Preferences
    var tipDeductionEnabled: Bool
    var effectivePersonalTaxRate: Double

    // Incremental Sync Settings
    var incrementalSyncEnabled: Bool
    var syncFrequency: String
    var lastIncrementalSyncDate: Date?
}
