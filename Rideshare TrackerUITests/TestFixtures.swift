//
//  TestFixtures.swift
//  Rideshare TrackerUITests
//
//  Created by Claude on 9/22/25.
//

import Foundation

/// Test fixtures designed to eliminate over-execution of business logic
/// Based on coverage analysis showing 782 hits on RideshareShift.init()
/// and 108 hits on shiftGasUsage() (96 unnecessary guard failures)
struct TestFixtures {

    // MARK: - UI Navigation Mocks (90% of test cases)

    /// Minimal data for UI navigation tests - avoids business logic execution
    /// Use this instead of creating full RideshareShift objects for menu navigation
    struct UINavigationMocks {

        nonisolated(unsafe) static let minimalShiftForListDisplay: [String: Any] = [
            "id": "ui-test-shift-001",
            "startDate": Date(),
            "endDate": Date().addingTimeInterval(3600), // 1 hour later
            "startLocation": "Test Location",
            "endLocation": "Test End Location",
            "startOdometer": 100.0,
            "endOdometer": 150.0
            // Intentionally missing tank readings and complex data
            // This prevents business logic calculations during UI navigation
        ]

        nonisolated(unsafe) static let minimalExpenseForListDisplay: [String: Any] = [
            "id": "ui-test-expense-001",
            "date": Date(),
            "amount": 25.50,
            "category": "Fuel",
            "description": "Test gas purchase"
            // Minimal data for UI list display only
        ]

        /// Multiple shifts for list testing without business logic overhead
        nonisolated(unsafe) static let multipleShiftsForUI: [[String: Any]] = [
            minimalShiftForListDisplay,
            [
                "id": "ui-test-shift-002",
                "startDate": Date().addingTimeInterval(-86400), // Yesterday
                "endDate": Date().addingTimeInterval(-82800),   // Yesterday + 1h
                "startLocation": "Location A",
                "endLocation": "Location B",
                "startOdometer": 200.0,
                "endOdometer": 235.0
            ],
            [
                "id": "ui-test-shift-003",
                "startDate": Date().addingTimeInterval(-172800), // 2 days ago
                "endDate": Date().addingTimeInterval(-169200),   // 2 days ago + 1h
                "startLocation": "Location C",
                "endLocation": "Location D",
                "startOdometer": 300.0,
                "endOdometer": 342.0
            ]
        ]
    }

    // MARK: - Business Logic Test Fixtures (10% of test cases)

    /// Complete data for business logic calculation testing
    /// Use these ONLY when testing actual calculations, not UI navigation
    struct CalculationFixtures {

        /// Complete shift with all data needed for gas calculations
        /// Designed to pass all guard statements and test actual business logic
        nonisolated(unsafe) static let completeShiftForGasCalculation: [String: Any] = [
            "id": "calc-test-shift-001",
            "startDate": Date(),
            "endDate": Date().addingTimeInterval(3600),
            "startLocation": "Start Location",
            "endLocation": "End Location",
            "startOdometer": 100.0,
            "endOdometer": 150.0,
            "startTankReading": 8.0,  // Full tank (8/8 scale)
            "endTankReading": 4.0,    // Half tank (4/8 scale)
            "refuelGallons": 0.0,     // No refuel
            "revenue": 75.0,
            "tips": 15.0,
            "tollExpense": 5.0,
            "parkingFees": 3.0,
            "miscFees": 0.0
        ]

        /// Shift with refueling scenario for testing refuel logic
        nonisolated(unsafe) static let shiftWithRefuel: [String: Any] = [
            "id": "calc-test-shift-002",
            "startDate": Date(),
            "endDate": Date().addingTimeInterval(7200), // 2 hours
            "startLocation": "Start Location",
            "endLocation": "End Location",
            "startOdometer": 200.0,
            "endOdometer": 280.0,
            "startTankReading": 6.0,  // 6/8 tank
            "endTankReading": 8.0,    // Full tank (after refuel)
            "refuelGallons": 10.0,    // Added 10 gallons
            "revenue": 120.0,
            "tips": 25.0,
            "tollExpense": 8.0,
            "parkingFees": 5.0,
            "miscFees": 2.0
        ]

        /// Edge case: Empty tank scenario
        nonisolated(unsafe) static let shiftWithEmptyTank: [String: Any] = [
            "id": "calc-test-shift-003",
            "startDate": Date(),
            "endDate": Date().addingTimeInterval(1800), // 30 minutes
            "startLocation": "Start Location",
            "endLocation": "End Location",
            "startOdometer": 300.0,
            "endOdometer": 315.0,
            "startTankReading": 1.0,  // Almost empty
            "endTankReading": 0.0,    // Empty tank
            "refuelGallons": 0.0,     // No refuel
            "revenue": 30.0,
            "tips": 5.0,
            "tollExpense": 0.0,
            "parkingFees": 0.0,
            "miscFees": 0.0
        ]
    }

    // MARK: - Form Validation Fixtures

    /// Data specifically for testing form validation scenarios
    struct ValidationFixtures {

        nonisolated(unsafe) static let invalidShiftData: [String: Any] = [
            "id": "validation-test-001",
            // Missing required fields for validation testing
            "startLocation": "",  // Empty location
            "startOdometer": -10.0,  // Negative odometer
            "endOdometer": 5.0,      // End less than start
        ]

        nonisolated(unsafe) static let invalidExpenseData: [String: Any] = [
            "id": "validation-expense-001",
            "amount": -5.0,  // Negative amount
            "category": "",  // Empty category
            "description": ""  // Empty description
        ]
    }

    // MARK: - Preference/Settings Test Data

    struct SettingsFixtures {
        nonisolated(unsafe) static let testPreferences: [String: Any] = [
            "tankCapacity": 16.0,
            "gasPrice": 3.50,
            "mileageRate": 0.67,
            "weekStartDay": 1, // Monday
            "dateFormat": "MM/dd/yyyy",
            "timeFormat": "12h"
        ]
    }
}

/// Helper for determining which fixture type to use based on test purpose
enum TestDataStrategy {
    case uiNavigationOnly    // Use UINavigationMocks - no business logic
    case businessLogicTest   // Use CalculationFixtures - full data
    case formValidation      // Use ValidationFixtures - test edge cases
    case settingsTest        // Use SettingsFixtures - preference data
}

/// Extension to help choose appropriate test data strategy
extension TestDataStrategy {

    /// Returns appropriate test data based on test strategy
    /// This helps developers choose the right fixtures to avoid over-execution
    static func recommendStrategy(for testDescription: String) -> TestDataStrategy {
        let description = testDescription.lowercased()

        if description.contains("navigation") || description.contains("display") ||
           description.contains("list") || description.contains("menu") {
            return .uiNavigationOnly
        } else if description.contains("calculation") || description.contains("gas") ||
                  description.contains("profit") || description.contains("cost") {
            return .businessLogicTest
        } else if description.contains("validation") || description.contains("error") ||
                  description.contains("invalid") {
            return .formValidation
        } else if description.contains("settings") || description.contains("preferences") {
            return .settingsTest
        } else {
            // Default to UI navigation for unknown test types
            return .uiNavigationOnly
        }
    }
}