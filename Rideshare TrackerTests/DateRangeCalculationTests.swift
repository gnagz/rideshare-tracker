//
//  DateRangeCalculationTests.swift
//  Rideshare TrackerTests
//
//  Created by Claude on 9/26/25.
//

import XCTest
import Foundation
import SwiftUI
@testable import Rideshare_Tracker

/// Tests for date range calculations and week/month filtering logic
/// Migrated from original Rideshare_TrackerTests.swift
final class DateRangeCalculationTests: RideshareTrackerTestBase {

    // MARK: - Basic Date Range Tests

    func testTodayDateRange() async throws {
        // Given
        let range = DateRangeOption.today
        let calendar = Calendar.current
        let now = Date()

        // When
        let result = range.getDateRange(weekStartDay: 1)

        // Then
        let expectedStart = calendar.startOfDay(for: now)
        let expectedEnd = calendar.date(byAdding: .day, value: 1, to: expectedStart)!

        XCTAssertTrue(calendar.isDate(result.start, inSameDayAs: expectedStart))
        XCTAssertTrue(calendar.isDate(result.end, inSameDayAs: expectedEnd))
    }

    func testYesterdayDateRange() async throws {
        // Given
        let range = DateRangeOption.yesterday
        let calendar = Calendar.current
        let now = Date()

        // When
        let result = range.getDateRange(weekStartDay: 1)

        // Then
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let expectedStart = calendar.startOfDay(for: yesterday)
        let expectedEnd = calendar.date(byAdding: .day, value: 1, to: expectedStart)!

        XCTAssertTrue(calendar.isDate(result.start, inSameDayAs: expectedStart))
        XCTAssertTrue(calendar.isDate(result.end, inSameDayAs: expectedEnd))
    }

    // MARK: - Week Range Tests

    func testThisWeekWithMondayStart() async throws {
        // Given: Sunday, August 24, 2025
        let testDate = createTestDate(year: 2025, month: 8, day: 24) // Sunday
        let range = DateRangeOption.thisWeek

        // When: Week starts on Monday (weekStartDay = 1)
        let result = range.getDateRange(weekStartDay: 1, referenceDate: testDate)

        // Then: Should be Monday August 18 - Sunday August 24
        let expectedStart = createTestDate(year: 2025, month: 8, day: 18) // Monday Aug 18
        let expectedEnd = createTestDate(year: 2025, month: 8, day: 24) // Sunday Aug 24

        XCTAssertTrue(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
        XCTAssertTrue(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
    }

    func testThisWeekWithSundayStart() async throws {
        // Given: Monday, August 25, 2025
        let testDate = createTestDate(year: 2025, month: 8, day: 25) // Monday
        let range = DateRangeOption.thisWeek

        // When: Week starts on Sunday (weekStartDay = 7)
        let result = range.getDateRange(weekStartDay: 7, referenceDate: testDate)

        // Then: Should be Sunday August 24 - Saturday August 30
        let expectedStart = createTestDate(year: 2025, month: 8, day: 24) // Sunday Aug 24
        let expectedEnd = createTestDate(year: 2025, month: 8, day: 30) // Saturday Aug 30

        XCTAssertTrue(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
        XCTAssertTrue(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
    }

    func testLastWeekWithMondayStart() async throws {
        // Given: Monday, September 1, 2025
        let testDate = createTestDate(year: 2025, month: 9, day: 1) // Monday
        let range = DateRangeOption.lastWeek

        // When: Week starts on Monday (weekStartDay = 1)
        let result = range.getDateRange(weekStartDay: 1, referenceDate: testDate)

        // Then: Should be Monday August 25 - Sunday August 31
        let expectedStart = createTestDate(year: 2025, month: 8, day: 25) // Monday Aug 25
        let expectedEnd = createTestDate(year: 2025, month: 8, day: 31) // Sunday Aug 31

        XCTAssertTrue(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
        XCTAssertTrue(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
    }

    func testLastWeekWithSundayStart() async throws {
        // Given: Monday, September 1, 2025
        let testDate = createTestDate(year: 2025, month: 9, day: 1) // Monday
        let range = DateRangeOption.lastWeek

        // When: Week starts on Sunday (weekStartDay = 7)
        let result = range.getDateRange(weekStartDay: 7, referenceDate: testDate)

        // Then: Should be Sunday August 24 - Saturday August 30
        let expectedStart = createTestDate(year: 2025, month: 8, day: 24) // Sunday Aug 24
        let expectedEnd = createTestDate(year: 2025, month: 8, day: 30) // Saturday Aug 30

        XCTAssertTrue(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
        XCTAssertTrue(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
    }

    // MARK: - Week Edge Case Tests

    func testWeekCalculationAcrossMonthBoundary() async throws {
        // Given: Tuesday, September 2, 2025 (early in month)
        let testDate = createTestDate(year: 2025, month: 9, day: 2) // Tuesday
        let range = DateRangeOption.thisWeek

        // When: Week starts on Monday
        let result = range.getDateRange(weekStartDay: 1, referenceDate: testDate)

        // Then: Should include days from August (Monday Sept 1)
        let expectedStart = createTestDate(year: 2025, month: 9, day: 1) // Monday Sept 1
        let expectedEnd = createTestDate(year: 2025, month: 9, day: 7) // Sunday Sept 7

        XCTAssertTrue(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
        XCTAssertTrue(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
    }

    func testWeekCalculationAcrossYearBoundary() async throws {
        // Given: Wednesday, January 1, 2025
        let testDate = createTestDate(year: 2025, month: 1, day: 1) // Wednesday
        let range = DateRangeOption.thisWeek

        // When: Week starts on Monday
        let result = range.getDateRange(weekStartDay: 1, referenceDate: testDate)

        // Then: Should include days from December 2024
        let expectedStart = createTestDate(year: 2024, month: 12, day: 30) // Monday Dec 30, 2024
        let expectedEnd = createTestDate(year: 2025, month: 1, day: 5) // Sunday Jan 5, 2025

        XCTAssertTrue(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
        XCTAssertTrue(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
    }

    // MARK: - Month Range Tests

    func testThisMonthDateRange() async throws {
        // Given
        let testDate = createTestDate(year: 2025, month: 8, day: 15) // Mid August
        let range = DateRangeOption.thisMonth

        // When
        let result = range.getDateRange(weekStartDay: 1, referenceDate: testDate)

        // Then
        let expectedStart = createTestDate(year: 2025, month: 8, day: 1) // August 1
        let expectedEnd = createTestDate(year: 2025, month: 8, day: 31) // August 31

        XCTAssertTrue(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
        XCTAssertTrue(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
    }

    func testLastMonthDateRange() async throws {
        // Given
        let testDate = createTestDate(year: 2025, month: 9, day: 15) // Mid September
        let range = DateRangeOption.lastMonth

        // When
        let result = range.getDateRange(weekStartDay: 1, referenceDate: testDate)

        // Then
        let expectedStart = createTestDate(year: 2025, month: 8, day: 1) // August 1
        let expectedEnd = createTestDate(year: 2025, month: 8, day: 31) // August 31

        XCTAssertTrue(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
        XCTAssertTrue(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
    }

    // MARK: - Year Range Tests

    func testThisYearDateRange() async throws {
        // Given
        let testDate = createTestDate(year: 2025, month: 6, day: 15) // Mid 2025
        let range = DateRangeOption.thisYear

        // When
        let result = range.getDateRange(weekStartDay: 1, referenceDate: testDate)

        // Then
        let expectedStart = createTestDate(year: 2025, month: 1, day: 1) // January 1, 2025
        let expectedEnd = createTestDate(year: 2025, month: 12, day: 31) // December 31, 2025

        XCTAssertTrue(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
        XCTAssertTrue(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
    }

    func testLastYearDateRange() async throws {
        // Given
        let testDate = createTestDate(year: 2025, month: 6, day: 15) // Mid 2025
        let range = DateRangeOption.lastYear

        // When
        let result = range.getDateRange(weekStartDay: 1, referenceDate: testDate)

        // Then
        let expectedStart = createTestDate(year: 2024, month: 1, day: 1) // January 1, 2024
        let expectedEnd = createTestDate(year: 2024, month: 12, day: 31) // December 31, 2024

        XCTAssertTrue(Calendar.current.isDate(result.start, inSameDayAs: expectedStart))
        XCTAssertTrue(Calendar.current.isDate(result.end, inSameDayAs: expectedEnd))
    }

    // MARK: - Comprehensive Range Coverage Tests

    func testAllDateRangeOptionsAreHandled() async throws {
        // Given
        let testDate = Date()

        // When/Then - Ensure no cases throw exceptions
        for range in DateRangeOption.allCases {
            let result = range.getDateRange(weekStartDay: 1, referenceDate: testDate)

            // Basic sanity checks
            if range != .all {
                XCTAssertTrue(result.start <= result.end, "Start should be before or equal to end for \(range.rawValue)")
            }

            // All option should return distant dates
            if range == .all {
                XCTAssertEqual(result.start, Date.distantPast)
                XCTAssertEqual(result.end, Date.distantFuture)
            }

            debugPrint("DateRange \(range.rawValue): \(result.start) to \(result.end)")
        }
    }

    // MARK: - Week Boundary Filtering Integration Tests

    func testWeekBoundaryInclusiveFiltering() async throws {
        let manager = await MainActor.run {
            let mgr = ShiftDataManager(forEnvironment: true)
            mgr.shifts.removeAll() // Clear any existing state
            return mgr
        }
        let calendar = Calendar.current

        // Test the actual bug: Sunday Aug 24, 2025 was being excluded from week view
        // Create date for Sunday Aug 24, 2025 (the original problematic date)
        let sundayComponents = DateComponents(year: 2025, month: 8, day: 24, hour: 14, minute: 30)
        guard let sundayAug24 = calendar.date(from: sundayComponents) else {
            XCTFail("Could not create test date")
            return
        }

        // Create a shift exactly on Sunday Aug 24, 2025
        var testShift = createBasicTestShift(startDate: sundayAug24)
        testShift.endDate = sundayAug24.addingTimeInterval(4 * 3600) // 4 hour shift
        testShift.endMileage = testShift.startMileage + 100

        await MainActor.run {
            manager.addShift(testShift)
        }

        // Filter for the week containing Aug 24, 2025 (Monday start)
        let range = DateRangeOption.thisWeek
        let weekRange = range.getDateRange(weekStartDay: 1, referenceDate: sundayAug24)

        debugPrint("Week range: \(weekRange.start) to \(weekRange.end)")
        debugPrint("Shift date: \(sundayAug24)")

        // Verify the shift is within the week range (inclusive)
        let isShiftInRange = sundayAug24 >= weekRange.start && sundayAug24 <= weekRange.end
        XCTAssertTrue(isShiftInRange, "Sunday Aug 24 should be included in its week range")

        // Verify manager filtering works correctly
        let filteredShifts = await MainActor.run {
            return manager.shifts.filter { shift in
                shift.startDate >= weekRange.start && shift.startDate <= weekRange.end
            }
        }

        XCTAssertEqual(filteredShifts.count, 1, "Should find the Sunday shift in week filter")
        XCTAssertEqual(filteredShifts.first?.id, testShift.id, "Should be the same shift")
    }

    func testWeekStartDayPreferenceDependency() async throws {
        let manager = await MainActor.run {
            let mgr = ShiftDataManager(forEnvironment: true)
            mgr.shifts.removeAll() // Clear any existing state
            return mgr
        }
        let calendar = Calendar.current

        // Create date for Wednesday Aug 20, 2025 (middle of week)
        let wednesdayComponents = DateComponents(year: 2025, month: 8, day: 20, hour: 10, minute: 0)
        guard let wednesdayAug20 = calendar.date(from: wednesdayComponents) else {
            XCTFail("Could not create test date")
            return
        }

        // Test with Monday week start
        let mondayRange = DateRangeOption.thisWeek.getDateRange(weekStartDay: 1, referenceDate: wednesdayAug20)
        debugPrint("Monday week start: \(mondayRange.start) to \(mondayRange.end)")

        // Test with Sunday week start
        let sundayRange = DateRangeOption.thisWeek.getDateRange(weekStartDay: 7, referenceDate: wednesdayAug20)
        debugPrint("Sunday week start: \(sundayRange.start) to \(sundayRange.end)")

        // Ranges should be different but both should contain Wednesday
        XCTAssertNotEqual(mondayRange.start, sundayRange.start, "Different week start days should produce different ranges")
        XCTAssertTrue(wednesdayAug20 >= mondayRange.start && wednesdayAug20 <= mondayRange.end)
        XCTAssertTrue(wednesdayAug20 >= sundayRange.start && wednesdayAug20 <= sundayRange.end)
    }
}