//
//  CalculatorEngineTests.swift
//  Rideshare TrackerTests
//
//  Created by Claude on 9/26/25.
//

import XCTest
import Foundation
import SwiftUI
@testable import Rideshare_Tracker

/// Tests for CalculatorEngine math expression evaluation
/// Migrated from original Rideshare_TrackerTests.swift
final class MathCalculatorTests: RideshareTrackerTestBase {

    // MARK: - Basic Arithmetic Tests

    func testBasicArithmetic() async throws {
        let calculator = await MainActor.run { CalculatorEngine.shared }

        // Basic operations
        XCTAssertEqual(calculator.evaluate("45+23"), 68.0)
        XCTAssertEqual(calculator.evaluate("100-25"), 75.0)
        XCTAssertEqual(calculator.evaluate("50*2"), 100.0)
        XCTAssertEqual(calculator.evaluate("100/4"), 25.0)

        // Decimal operations
        let result1 = calculator.evaluate("12.50+3.75")
        XCTAssertNotNil(result1)
        if let val = result1 {
            assertCurrency(val, equals: 16.25, "Should calculate decimal addition correctly")
        }

        let result2 = calculator.evaluate("100.5*0.67")
        XCTAssertNotNil(result2)
        if let val = result2 {
            assertCurrency(val, equals: 67.335, "Should calculate decimal multiplication correctly")
        }
    }

    func testRideshareScenarios() async throws {
        let calculator = await MainActor.run { CalculatorEngine.shared }

        // Scenarios from rideshare shifts
        XCTAssertEqual(calculator.evaluate("250-175"), 75.0)   // Mileage calculation (end - start)
        XCTAssertEqual(calculator.evaluate("45/3"), 15.0)      // Tip splitting
        XCTAssertEqual(calculator.evaluate("65*0.75"), 48.75)  // Fuel costs
        XCTAssertEqual(calculator.evaluate("150*0.67"), 100.5) // Tax deductions (IRS rate)

        // Expense calculations
        XCTAssertEqual(calculator.evaluate("12.50+3.50"), 16.0)  // Meal + tip
        XCTAssertEqual(calculator.evaluate("25+15+8"), 48.0)     // Multiple expenses
    }

    func testComplexExpressions() async throws {
        let calculator = await MainActor.run { CalculatorEngine.shared }

        // Parentheses and order of operations
        XCTAssertEqual(calculator.evaluate("(100+50)*0.67"), 100.5)
        XCTAssertEqual(calculator.evaluate("100+50*2-25/5"), 195.0)
        XCTAssertEqual(calculator.evaluate("(250-175)*0.67"), 50.25) // Miles times IRS rate
    }

    // MARK: - Expression Detection Tests

    func testExpressionDetection() async throws {
        let calculator = await MainActor.run { CalculatorEngine.shared }

        // Should detect math expressions
        XCTAssertEqual(calculator.containsMathExpression("45+23"), true)
        XCTAssertEqual(calculator.containsMathExpression("100*0.67"), true)
        XCTAssertTrue(calculator.containsMathExpression("250-175=") == true)

        // Should not detect plain numbers
        XCTAssertEqual(calculator.containsMathExpression("45"), false)
        XCTAssertEqual(calculator.containsMathExpression("123.45"), false)
        XCTAssertEqual(calculator.containsMathExpression(""), false)
    }

    func testInputSanitization() async throws {
        let calculator = await MainActor.run { CalculatorEngine.shared }

        // Should handle equals sign at end
        XCTAssertTrue(calculator.evaluate("45+23=") == 68.0)
        XCTAssertTrue(calculator.evaluate("100/4=") == 25.0)

        // Should handle alternative math symbols
        XCTAssertEqual(calculator.evaluate("50×2"), 100.0)  // Multiplication symbol
        XCTAssertEqual(calculator.evaluate("100÷4"), 25.0)  // Division symbol
        XCTAssertEqual(calculator.evaluate("100−25"), 75.0) // En-dash minus
    }

    func testErrorHandling() async throws {
        let calculator = await MainActor.run { CalculatorEngine.shared }

        // Invalid expressions should return nil
        XCTAssertEqual(calculator.evaluate("invalid"), nil)
        XCTAssertEqual(calculator.evaluate("45+"), nil)
        XCTAssertEqual(calculator.evaluate("+45"), nil)
        XCTAssertEqual(calculator.evaluate("45++23"), nil)
        XCTAssertEqual(calculator.evaluate("("), nil)
        XCTAssertTrue(calculator.evaluate("45/0") != nil) // Division by zero should be handled by NSExpression
    }

    // MARK: - Real World Scenario Tests

    func testMultipleRefuelingScenario() async throws {
        let calculator = await MainActor.run { CalculatorEngine.shared }

        // Real scenario: refueling more than once
        // Fuel costs: First fill $45.67, second fill $38.25
        XCTAssertEqual(calculator.evaluate("45.67+38.25"), 83.92)

        // Gallons used: First 12.5 gallons, second 10.75 gallons
        let totalGallons = calculator.evaluate("12.5+10.75")
        XCTAssertEqual(totalGallons, 23.25)

        // Average cost per gallon across both fills
        let avgCostPerGallon = calculator.evaluate("83.92/23.25")
        XCTAssertNotNil(avgCostPerGallon)
        if let avg = avgCostPerGallon {
            XCTAssertTrue(abs(avg - 3.609) < 0.01, "Should calculate average cost per gallon")
        }
    }

    func testRealWorldRideshareScenarios() async throws {
        let calculator = await MainActor.run { CalculatorEngine.shared }

        // After 12-hour shift calculations
        // Multiple platform earnings: Uber + Lyft + DoorDash
        XCTAssertEqual(calculator.evaluate("125.50+87.25+45.75"), 258.5)

        // Tip calculations with cash tips included
        XCTAssertEqual(calculator.evaluate("35.75+12+8.50"), 56.25)

        // Toll road costs throughout day
        XCTAssertEqual(calculator.evaluate("3.50+2.75+4.25+3.50"), 14.0)

        // Parking fees: downtown + airport + garage
        XCTAssertEqual(calculator.evaluate("8+5+12"), 25.0)

        // Net profit after all expenses
        let revenue = calculator.evaluate("258.5+56.25") // Fare + tips
        let expenses = calculator.evaluate("83.92+14+25") // Fuel + tolls + parking
        XCTAssertEqual(revenue, 314.75)
        XCTAssertEqual(expenses, 122.92)

        // Quick profit check
        let profit = calculator.evaluate("314.75-122.92")
        XCTAssertNotNil(profit)
        if let profitVal = profit {
            XCTAssertTrue(abs(profitVal - 191.83) < 0.01, "Should calculate profit correctly")
        }
    }
}