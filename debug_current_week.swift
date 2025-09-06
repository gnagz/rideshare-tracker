import Foundation

let calendar = Calendar.current
let today = Date()

// Create a Sunday date from this past Sunday
let sundayAug31 = calendar.date(from: DateComponents(year: 2025, month: 8, day: 31))! // Sunday Aug 31, 2025

func getWeekInterval(for date: Date, weekStartDay: Int) -> DateInterval {
    let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    
    // Find the user's preferred week start day
    let preferredWeekStart = weekStartDay == 1 ? 1 : 2 // 1 = Sunday, 2 = Monday
    let currentWeekStart = calendar.component(.weekday, from: startOfWeek)
    
    var adjustedStart = startOfWeek
    if currentWeekStart != preferredWeekStart {
        let dayDifference = preferredWeekStart - currentWeekStart
        adjustedStart = calendar.date(byAdding: .day, value: dayDifference, to: startOfWeek) ?? startOfWeek
        
        // If the adjustment puts us in the future, go back a week
        if adjustedStart > date {
            adjustedStart = calendar.date(byAdding: .weekOfYear, value: -1, to: adjustedStart) ?? adjustedStart
        }
    }
    
    let endOfWeek = calendar.date(byAdding: .day, value: 6, to: adjustedStart) ?? adjustedStart
    return DateInterval(start: adjustedStart, end: endOfWeek)
}

let formatter = DateFormatter()
formatter.dateFormat = "EEEE, MMM d, yyyy 'at' h:mm a"
formatter.timeZone = TimeZone.current

print("Current time: \(formatter.string(from: today))")
print()

// Test current week with Monday start
let currentWeekInterval = getWeekInterval(for: today, weekStartDay: 2)
print("Current week (Monday start):")
print("  Start: \(formatter.string(from: currentWeekInterval.start))")
print("  End: \(formatter.string(from: currentWeekInterval.end))")
print()

print("Sunday Aug 31 shift:")
print("  Date: \(formatter.string(from: sundayAug31))")
print("  In current week? \(sundayAug31 >= currentWeekInterval.start && sundayAug31 <= currentWeekInterval.end)")
print()

// Test previous week
let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: today)!
let lastWeekInterval = getWeekInterval(for: lastWeek, weekStartDay: 2)
print("Last week (Monday start):")
print("  Start: \(formatter.string(from: lastWeekInterval.start))")
print("  End: \(formatter.string(from: lastWeekInterval.end))")
print("  Sunday Aug 31 in last week? \(sundayAug31 >= lastWeekInterval.start && sundayAug31 <= lastWeekInterval.end)")