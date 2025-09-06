import Foundation

let calendar = Calendar.current

// Let's test with today being Monday Sept 2, and a Sunday shift on Sept 1
let mondaySept2 = calendar.date(from: DateComponents(year: 2025, month: 9, day: 2))! // Monday Sept 2, 2025  
let sundaySept1 = calendar.date(from: DateComponents(year: 2025, month: 9, day: 1))! // Sunday Sept 1, 2025

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

print("Testing Monday week start scenario:")
print("Selected date: Monday Sept 2, 2025")
print("Shift date: Sunday Sept 1, 2025")
print()

// Test Monday week start (weekStartDay = 2)
let weekInterval = getWeekInterval(for: mondaySept2, weekStartDay: 2)

let formatter = DateFormatter()
formatter.dateStyle = .full
formatter.timeStyle = .none

print("Week interval for Monday Sept 2 (Monday start):")
print("  Start: \(formatter.string(from: weekInterval.start))")
print("  End: \(formatter.string(from: weekInterval.end))")
print()

print("Sunday Sept 1 shift:")
print("  Date: \(formatter.string(from: sundaySept1))")
print("  In current week range? \(sundaySept1 >= weekInterval.start && sundaySept1 <= weekInterval.end)")
print()

// What if we're viewing the previous week?
let previousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: mondaySept2)!
let prevWeekInterval = getWeekInterval(for: previousWeek, weekStartDay: 2)

print("Previous week interval (Monday Aug 26 area):")
print("  Start: \(formatter.string(from: prevWeekInterval.start))")  
print("  End: \(formatter.string(from: prevWeekInterval.end))")
print("  Sunday Sept 1 in previous week? \(sundaySept1 >= prevWeekInterval.start && sundaySept1 <= prevWeekInterval.end)")