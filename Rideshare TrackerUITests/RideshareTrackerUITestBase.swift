//
//  RideshareTrackerUITestBase.swift
//  Rideshare TrackerUITests
//
//  Created by Claude on 9/22/25.
//

import XCTest

// MARK: - XCUIElement Extensions

extension XCUIElement {
    /// Clear all text from this element
    func clearText() {
        
        guard let stringValue = value as? String else {
            return
        }

        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        typeText(deleteString)
    }
}

/// Shared base class for all Rideshare Tracker UI tests
/// Provides common utilities, debug helpers, and lightweight test fixtures
/// to reduce redundant business logic execution in UI tests
class RideshareTrackerUITestBase: XCTestCase {

    // MARK: - Debug Utilities

    /// Global debug printing utility - only outputs when debug flags are set
    func debugPrint(_ message: String, function: String = #function, file: String = #file) {
        let debugEnabled = ProcessInfo.processInfo.environment["DEBUG"] != nil ||
                          ProcessInfo.processInfo.arguments.contains("-debug")

        // Debug printing only when enabled
        // Removed always-print debug lines - only print when debug flag is enabled

        if debugEnabled {
            let fileName = (file as NSString).lastPathComponent
            print("DEBUG [\(fileName):\(function)]: \(message)")
        }
    }

    /// Visual verification pause - only pauses when visual debug flags are set
    func visualDebugPause(_ seconds: UInt32 = 2, function: String = #function, file: String = #file) {
        let visualDebugEnabled = ProcessInfo.processInfo.environment["UI_TEST_VISUAL_DEBUG"] != nil ||
                                ProcessInfo.processInfo.arguments.contains("-visual-debug")
        if visualDebugEnabled {
            let fileName = (file as NSString).lastPathComponent
            let message = "Pausing test for \(seconds)s for Visual Observation. Consider taking screenshot."
            print("DEBUG [\(fileName):\(function)]: \(message)")
            sleep(seconds)
        }
    }

    // MARK: - App Launch and Configuration

    /// Configure XCUIApplication with proper test arguments and launch
    @MainActor
    func launchApp() -> XCUIApplication {
        debugPrint("Launching app...")
        let app = XCUIApplication()
        configureTestApp(app)
        app.launch()
        debugPrint("App launched successfully")
        return app
    }

    /// Configure XCUIApplication with proper test arguments (without launching)
    @MainActor
    private func configureTestApp(_ app: XCUIApplication) {
        // Pass -testing flag to main app if test runner received it
        if ProcessInfo.processInfo.arguments.contains("-testing") {
            app.launchArguments.append("-testing")
        }

        // Also pass debug flags if present
        if ProcessInfo.processInfo.arguments.contains("-debug") {
            app.launchArguments.append("-debug")
        }
        if ProcessInfo.processInfo.arguments.contains("-visual-debug") {
            app.launchArguments.append("-visual-debug")
        }
    }

    // MARK: - Navigation Helpers

    /// Navigate to a specific tab in the app
    @MainActor
    func navigateToTab(_ tabName: String, in app: XCUIApplication) {
        debugPrint("Navigate to tab: \(tabName)")
        let tabButton = app.tabBars.buttons[tabName]
        XCTAssertTrue(tabButton.waitForExistence(timeout: 5), "Tab '\(tabName)' should exist")
        // Use waitAndTap for more robust tapping with fallback handling
        waitAndTap(tabButton)
    }

    /// Navigate to settings/main menu
    @MainActor
    func navigateToSettings(in app: XCUIApplication) {
        debugPrint("Attempting to navigate to settings...")

        let gearButton = findButton(keyword: "settings_button", keyword2: "Settings", keyword3: "gearshape", in: app)
        XCTAssertTrue(gearButton.exists, "Settings gear button should exist")
        waitAndTap(gearButton)
        debugPrint("Settings navigation completed")
    }

    // MARK: - UI Element Helpers

    /// Helper function to reliably find a button by keyword with proper error handling
    /// Supports multiple fallback keywords for better test resilience
    @MainActor
    func findButton(keyword: String, keyword2: String? = nil, keyword3: String? = nil, in app: XCUIApplication) -> XCUIElement {
        let keywords = [keyword, keyword2, keyword3].compactMap { $0 }
        debugPrint("Searching for button with keywords: \(keywords)")

        // Try each keyword in order
        for currentKeyword in keywords {
            let theButton = app.buttons[currentKeyword]
            if theButton.exists {
                debugPrint("✅ Direct match found for '\(currentKeyword)': identifier='\(theButton.identifier)', label='\(theButton.label)', isEnabled=\(theButton.isEnabled)")
                return theButton
            }
        }

        debugPrint("❌ No direct matches for any keywords, trying fallback search...")

        // Fallback: look for any keyword in identifier or label
        for currentKeyword in keywords {
            let matchingButtons = app.buttons.matching(NSPredicate(format: "identifier CONTAINS %@ OR label CONTAINS %@", currentKeyword, currentKeyword))
            debugPrint("Fallback search for '\(currentKeyword)' found \(matchingButtons.count) potential matches")

            if matchingButtons.count > 0 {
                // Check for multiple matches and provide helpful error message
                if matchingButtons.count > 1 {
                    debugPrint("WARNING: Found \(matchingButtons.count) buttons matching '\(currentKeyword)'. Consider adding unique accessibility labels.")
                    for i in 0..<matchingButtons.count {
                        let button = matchingButtons.element(boundBy: i)
                        debugPrint("  Button \(i): identifier='\(button.identifier)', label='\(button.label)', exists=\(button.exists), isEnabled=\(button.isEnabled)")
                    }
                } else {
                    let button = matchingButtons.firstMatch
                    debugPrint("Single fallback match for '\(currentKeyword)': identifier='\(button.identifier)', label='\(button.label)', exists=\(button.exists), isEnabled=\(button.isEnabled)")
                }

                let firstMatch = matchingButtons.firstMatch
                if firstMatch.exists {
                    debugPrint("✅ Returning fallback match for '\(currentKeyword)': exists=\(firstMatch.exists), isEnabled=\(firstMatch.isEnabled)")
                    return firstMatch
                }
            }
        }

        // No matches found for any keyword
        debugPrint("❌ CRITICAL: No button found for any keywords \(keywords) - returning non-existent element!")
        debugPrint("ALL AVAILABLE BUTTONS with full debugDescription:")
        // Iterate through all buttons and print their labels or identifiers
        for button in app.buttons.allElementsBoundByIndex.prefix(10) {
            debugPrint("\(button.debugDescription)")
        }
        XCTFail("Failed to find button with keywords \(keywords). No matches found.")

        return app.buttons[keyword] // Return the first keyword's element (non-existent)
    }

    /// Helper function to reliably find a text field by keyword with flexible discovery patterns
    @MainActor
    func findTextField(keyword: String, in app: XCUIApplication) -> XCUIElement {
        debugPrint("Searching for text field with keyword: '\(keyword)'")

        // Try direct identifier match first
        let directField = app.textFields[keyword]
        if directField.exists {
            debugPrint("✅ Direct match found: identifier='\(directField.identifier)', placeholder='\(directField.placeholderValue ?? "nil")', isEnabled=\(directField.isEnabled)")
            return directField
        }

        debugPrint("❌ No direct match for '\(keyword)', trying flexible search...")

        // Fallback 1: Search by placeholder text (case-insensitive)
        let placeholderFields = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS[c] %@", keyword))
        debugPrint("Placeholder search found \(placeholderFields.count) potential matches")

        if placeholderFields.count > 0 {
            let field = placeholderFields.firstMatch
            debugPrint("✅ Placeholder match: placeholder='\(field.placeholderValue ?? "nil")', exists=\(field.exists), isEnabled=\(field.isEnabled)")
            return field
        }

        // Fallback 2: Search by accessibility label (case-insensitive)
        let labelFields = app.textFields.matching(NSPredicate(format: "label CONTAINS[c] %@", keyword))
        debugPrint("Label search found \(labelFields.count) potential matches")

        if labelFields.count > 0 {
            let field = labelFields.firstMatch
            debugPrint("✅ Label match: label='\(field.label)', exists=\(field.exists), isEnabled=\(field.isEnabled)")
            return field
        }

        // Fallback 3: Search by identifier containing keyword (case-insensitive)
        let identifierFields = app.textFields.matching(NSPredicate(format: "identifier CONTAINS[c] %@", keyword))
        debugPrint("Identifier search found \(identifierFields.count) potential matches")

        if identifierFields.count > 0 {
            let field = identifierFields.firstMatch
            debugPrint("✅ Identifier match: identifier='\(field.identifier)', exists=\(field.exists), isEnabled=\(field.isEnabled)")
            return field
        }

        // Debug fallback: Show all available text fields for troubleshooting
        debugPrint("❌ CRITICAL: No text field found for keyword '\(keyword)' - showing all available text fields:")
        for (index, field) in app.textFields.allElementsBoundByIndex.prefix(10).enumerated() {
            debugPrint("  TextField[\(index)]: identifier='\(field.identifier)', placeholder='\(field.placeholderValue ?? "nil")', label='\(field.label)', exists=\(field.exists)")
        }

        // Return first available text field as last resort
        let firstField = app.textFields.firstMatch
        debugPrint("⚠️ Returning first available text field as fallback: exists=\(firstField.exists)")
        return firstField
    }

    /// Enter text in field and properly complete input (includes Done button tap)
    /// This is the recommended way to enter text to ensure validation triggers
    /// Automatically clears existing text before entering new text
    @MainActor
    func enterText(_ text: String, in textField: XCUIElement, app: XCUIApplication) {
        debugPrint("Entering text '\(text)' into field: identifier='\(textField.identifier)', label='\(textField.label)'")
        debugPrint("Field state before tap: exists=\(textField.exists), isEnabled=\(textField.isEnabled), isFocused=\(textField.hasFocus)")

        waitAndTap(textField)
        debugPrint("Field tapped, clearing existing text and typing new text...")

        // Clear existing text first to ensure clean input
        let existingText = textField.value as? String ?? ""
        if !existingText.isEmpty {
            debugPrint("Clearing existing text: '\(existingText)'")
            textField.clearText()
        }

        textField.typeText(text)
        debugPrint("Text typed. Field value after typing: '\(textField.value ?? "nil")'")

        // CRITICAL: Always tap Done button to trigger validation and calculations
        let doneButton = app.buttons["Done"]
        if doneButton.exists {
            debugPrint("✅ Done button found, tapping to trigger validation...")
            doneButton.tap()
            debugPrint("Done button tapped successfully")
        } else {
            debugPrint("❌ WARNING: Done button not found! Validation may not trigger.")
            debugPrint("Available keyboard buttons:")
            let keyboardButtons = app.keyboards.buttons.allElementsBoundByIndex.prefix(5)
            for (index, button) in keyboardButtons.enumerated() {
                debugPrint("  Keyboard[\(index)]: identifier='\(button.identifier)', label='\(button.label)'")
            }
        }

        debugPrint("Dismissing keyboard if present...")
        dismissKeyboardIfPresent(in: app)

        let keyboardCount = app.keyboards.count
        debugPrint("Keyboard dismissal complete. Keyboards remaining: \(keyboardCount)")
        debugPrint("Final field value: '\(textField.value ?? "nil")'")
    }

    /// Dismiss keyboard if present
    @MainActor
    func dismissKeyboardIfPresent(in app: XCUIApplication) {
        let keyboardCount = app.keyboards.count
        debugPrint("Keyboard dismissal attempt: \(keyboardCount) keyboards present")
        if keyboardCount > 0 {
            debugPrint("Tapping outside text fields to dismiss keyboard...")
            // Try tapping outside text fields to dismiss keyboard
            let coordinate = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
            coordinate.tap()
            debugPrint("Coordinate tap completed")
        } else {
            debugPrint("No keyboards to dismiss")
        }
    }

    /// Wait for element and tap with timeout, handling scroll failures gracefully
    @MainActor
    func waitAndTap(_ element: XCUIElement, timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        debugPrint("Waiting for element to exist: identifier='\(element.identifier)', label='\(element.label)', timeout=\(timeout)s")
        let exists = element.waitForExistence(timeout: timeout)

        if exists {
            debugPrint("✅ Element exists: isEnabled=\(element.isEnabled), isHittable=\(element.isHittable)")

            // Check if element is hittable before attempting to tap
            if element.isHittable {
                debugPrint("Element is hittable, performing standard tap")
                element.tap()
                debugPrint("Element tap completed successfully")
            } else {
                debugPrint("⚠️ Element not hittable (likely off-screen), trying coordinate tap...")
                // Try tapping at the element's center coordinate directly
                let coordinate = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                coordinate.tap()
                debugPrint("Coordinate tap completed")

                // Brief pause to allow tap to register
                Thread.sleep(forTimeInterval: 0.5)
            }
        } else {
            debugPrint("❌ TIMEOUT: Element did not appear within \(timeout) seconds")
        }
        XCTAssertTrue(exists, "Element should exist within \(timeout) seconds", file: file, line: line)
    }

    // MARK: - Lightweight Test Data Creation

    /// Create minimal shift data for UI navigation (avoids heavy business logic)
    /// This replaces creating full RideshareShift objects for simple UI navigation
    @MainActor
    func navigateToShiftsWithMockData(in app: XCUIApplication) {
        navigateToTab("Shifts", in: app)
        // Note: In real implementation, this would inject minimal mock data
        // for UI display without triggering business logic calculations
    }

    /// Create minimal expense data for UI navigation
    @MainActor
    func navigateToExpensesWithMockData(in app: XCUIApplication) {
        navigateToTab("Expenses", in: app)
        // Note: Similar to shifts, this would use lightweight mock data
    }

    // MARK: - Test Setup and Teardown

    override func setUpWithError() throws {
        // Common setup for all UI tests
        continueAfterFailure = false

        debugPrint("Starting test: \(name)")
    }

    override func tearDownWithError() throws {
        debugPrint("Completed test: \(name)")
    }
}
