//
//  RideshareTrackerTestBase.swift
//  Rideshare TrackerTests
//
//  Created by Claude on 9/26/25.
//

import XCTest
import Foundation
import SwiftUI
@testable import Rideshare_Tracker

/// Shared base class for all Rideshare Tracker unit tests
/// Provides common utilities, test fixtures, and debugging helpers
class RideshareTrackerTestBase: XCTestCase {

    // MARK: - Test Configuration

    /// Standard test values used across multiple tests
    struct TestConstants {
        static let defaultStartMileage: Double = 10000.0
        static let defaultEndMileage: Double = 10100.0
        static let defaultGasPrice: Double = 2.00
        static let defaultMileageRate: Double = 0.67
        static let defaultTankReading: Double = 8.0
        static let floatAccuracy: Double = 0.01
        static let currencyAccuracy: Double = 0.001
    }

    // MARK: - Debug Utilities

    /// Unit test debug printing - only outputs when test debug flags are set
    func debugPrint(_ message: String, function: String = #function, file: String = #file) {
        let debugEnabled = ProcessInfo.processInfo.environment["TEST_DEBUG"] != nil ||
                          ProcessInfo.processInfo.arguments.contains("-test-debug")

        if debugEnabled {
            let fileName = (file as NSString).lastPathComponent
            print("TEST_DEBUG [\(fileName):\(function)]: \(message)")
        }
    }

    // MARK: - Test Data Factory Methods

    /// Create a standard test shift with reasonable defaults
    func createBasicTestShift(
        startDate: Date = Date(),
        startMileage: Double = TestConstants.defaultStartMileage,
        startTankReading: Double = TestConstants.defaultTankReading,
        hasFullTankAtStart: Bool = true,
        gasPrice: Double = TestConstants.defaultGasPrice,
        standardMileageRate: Double = TestConstants.defaultMileageRate
    ) -> RideshareShift {
        debugPrint("Creating basic test shift with startMileage: \(startMileage)")
        return RideshareShift(
            startDate: startDate,
            startMileage: startMileage,
            startTankReading: startTankReading,
            hasFullTankAtStart: hasFullTankAtStart,
            gasPrice: gasPrice,
            standardMileageRate: standardMileageRate
        )
    }

    /// Create a completed test shift with end values
    func createCompletedTestShift(
        startDate: Date = Date(),
        endDate: Date? = nil,
        shiftHours: Double = 4.0,
        milesDriven: Double = 100.0,
        netFare: Double = 150.0,
        tips: Double = 25.0,
        tolls: Double = 0.0
    ) -> RideshareShift {
        let actualEndDate = endDate ?? startDate.addingTimeInterval(shiftHours * 3600)

        var shift = createBasicTestShift(startDate: startDate)
        shift.endDate = actualEndDate
        shift.endMileage = shift.startMileage + milesDriven
        shift.netFare = netFare
        shift.tips = tips
        shift.tolls = tolls

        debugPrint("Creating completed shift: \(shiftHours)h, \(milesDriven) miles, revenue: $\(netFare + tips)")
        return shift
    }

    /// Create test expense item with standard values
    func createTestExpense(
        date: Date = Date(),
        category: ExpenseCategory = .vehicle,
        description: String = "Test Expense",
        amount: Double = 25.00
    ) -> ExpenseItem {
        debugPrint("Creating test expense: \(description) - $\(amount)")
        return ExpenseItem(
            date: date,
            category: category,
            description: description,
            amount: amount
        )
    }

    /// Create test UI image with specified properties
    func createTestUIImage(
        size: CGSize = CGSize(width: 100, height: 100),
        color: UIColor = .systemBlue
    ) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()

        debugPrint("Created test image: \(size)")
        return image
    }

    // MARK: - Date Utilities

    /// Create date with specific components for testing
    func createTestDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 9,
        minute: Int = 0
    ) -> Date {
        let calendar = Calendar.current
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return calendar.date(from: components) ?? Date()
    }

    /// Create date relative to now for testing
    func createRelativeDate(daysFromNow: Int = 0, hoursFromNow: Double = 0) -> Date {
        return Date().addingTimeInterval(TimeInterval(daysFromNow * 86400) + TimeInterval(hoursFromNow * 3600))
    }

    // MARK: - Enhanced Assertions

    /// Assert currency values with appropriate precision
    func assertCurrency(_ actual: Double?, equals expected: Double, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        guard let actual = actual else {
            XCTFail("Expected currency value but got nil. \(message)", file: file, line: line)
            return
        }
        XCTAssertEqual(actual, expected, accuracy: TestConstants.currencyAccuracy, message, file: file, line: line)
    }

    /// Assert float values with standard precision
    func assertFloat(_ actual: Double?, equals expected: Double, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        guard let actual = actual else {
            XCTFail("Expected float value but got nil. \(message)", file: file, line: line)
            return
        }
        XCTAssertEqual(actual, expected, accuracy: TestConstants.floatAccuracy, message, file: file, line: line)
    }

    /// Assert non-optional currency values
    func assertCurrency(_ actual: Double, equals expected: Double, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual, expected, accuracy: TestConstants.currencyAccuracy, message, file: file, line: line)
    }

    /// Assert non-optional float values
    func assertFloat(_ actual: Double, equals expected: Double, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual, expected, accuracy: TestConstants.floatAccuracy, message, file: file, line: line)
    }

    /// Assert dates are on the same day
    func assertSameDay(_ actual: Date, _ expected: Date, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(Calendar.current.isDate(actual, inSameDayAs: expected), message, file: file, line: line)
    }

    // MARK: - Setup and Teardown

    override func setUpWithError() throws {
        try super.setUpWithError()
        debugPrint("Starting test: \(name)")
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        debugPrint("Completed test: \(name)")
        try super.tearDownWithError()
    }
}