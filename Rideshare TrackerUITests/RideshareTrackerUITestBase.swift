//
//  RideshareTrackerUITestBase.swift
//  Rideshare TrackerUITests
//
//  Created by Claude on 9/22/25.
//

import XCTest
import Foundation

// MARK: - XCUIElement Extensions

extension XCUIElement {
    /// Clear all text from this element
    func clearText(timeout: TimeInterval = 2.0) {
        // Get the label, defaulting to "text field" if nil or empty
        let fieldLabel = self.label.isEmpty ? "text field" : label

        guard let stringValue = self.value as? String else {
            debugMessage("Clear \(fieldLabel) of current value: 'nil'")
            return
        }

        debugMessage("Clear \(fieldLabel) of current value: '\(stringValue)'")

        // Clear existing text first to ensure clean input
        let characterCount = stringValue.count
        debugMessage("⚙️ Attempt to clear \(fieldLabel) using doubletap + delete, Cmd A + delete, and \(characterCount) right arrows + \(characterCount) delete keys")
        
        self.tap() // Ensure the element is focused and keyboard is up
        
        // Simulate backspace presses to clear existing text
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        self.typeText(deleteString)

        // If that doesn't work, try Cmd+A and one delete to clear selection
        self.typeKey("a", modifierFlags: .command)
        self.typeText(XCUIKeyboardKey.delete.rawValue)
        
        // Move cursor to end of text if the cursor isn't already there
//        let rightArrowString = String(repeating: XCUIKeyboardKey.rightArrow.rawValue, count: stringValue.count)

        // Simulate more backspace presses to clear existing text
        self.typeText(deleteString)

        // Poll for updated value
        let startTime = Date()
        var currentValue = value as? String
        let placeholderValue = placeholderValue ?? ""
        while currentValue != nil && !currentValue!.isEmpty && Date().timeIntervalSince(startTime) < timeout {
            currentValue = value as? String
            Thread.sleep(forTimeInterval: 0.1) // Small polling interval
        }

        guard let clearedValue = value as? String else {
            debugMessage("✅ After clearing, \(fieldLabel) value is nil.")
            return
        }
        if clearedValue.isEmpty || clearedValue == placeholderValue {
            debugMessage("✅ After clearing, \(fieldLabel) value is empty or showing placeholder.")
            return
        }
            
        debugMessage("❌ After clearing, \(fieldLabel) value is still not empty. Current value: '\(value as? String ?? "")'")
    }
}
/// Shared base class for all Rideshare Tracker UI tests
/// Provides common utilities, debug helpers, and lightweight test fixtures
/// to reduce redundant business logic execution in UI tests
class RideshareTrackerUITestBase: XCTestCase {

    // MARK: - App Preferences (Read from UI)

    /// Cached app preferences read from PreferencesView UI
    /// Populated by calling loadAppPreferencesStatic() from class setUp()
    /// Note: nonisolated(unsafe) because tests run sequentially, not concurrently
    nonisolated(unsafe) private static var cachedPreferences: [String: String] = [:]

    /// Error thrown when preference cannot be read
    enum PreferenceError: Error {
        case preferenceNotFound(String)
        case navigationFailed(String)

        var localizedDescription: String {
            switch self {
            case .preferenceNotFound(let key):
                return "Required preference '\(key)' not found. Did you call loadAppPreferences()?"
            case .navigationFailed(let reason):
                return "Failed to navigate to Preferences: \(reason)"
            }
        }
    }

    /// Get a cached preference value
    /// Throws PreferenceError.preferenceNotFound if not loaded
    func getPreference(_ key: String) throws -> String {
        guard let value = Self.cachedPreferences[key] else {
            throw PreferenceError.preferenceNotFound(key)
        }
        return value
    }

    /// Navigate to Preferences and read all values from UI
    /// Call this in setUp() to cache preferences for all tests in the class
    @MainActor
    func loadAppPreferences(in app: XCUIApplication) throws {
        debugMessage("📋 Loading app preferences from PreferencesView...")

        // Navigate to Main Menu (settings button)
        let settingsButton = app.buttons["settings_button"]
        guard settingsButton.waitForExistence(timeout: 3) else {
            throw PreferenceError.navigationFailed("Settings button not found")
        }
        waitAndTap(settingsButton)

        // Tap Preferences (it's a static text, not a button)
        let preferencesText = app.staticTexts["Preferences"]
        guard preferencesText.waitForExistence(timeout: 3) else {
            throw PreferenceError.navigationFailed("Preferences text not found")
        }
        waitAndTap(preferencesText)

        // Wait for view to load
        guard app.navigationBars["Preferences"].waitForExistence(timeout: 3) else {
            throw PreferenceError.navigationFailed("Preferences view did not load")
        }

        // Read pickers (use .value for accessibility value we added)
        let weekStartPicker = app.buttons["week_start_day_picker"]
        let dateFormatPicker = app.buttons["date_format_picker"]
        let timeFormatPicker = app.buttons["time_format_picker"]
        let timeZonePicker = app.buttons["time_zone_picker"]

        // Read text fields (use .value)
        let tankCapacityField = app.textFields["tank_capacity_field"]
        let gasPriceField = app.textFields["gas_price_field"]
        let mileageRateField = app.textFields["mileage_rate_field"]
        let taxRateField = app.textFields["tax_rate_field"]

        // Read toggle (use .value - returns "0" or "1")
        let tipToggle = app.switches["tip_deduction_toggle"]

        // Store values using accessibilityValue we added
        Self.cachedPreferences["weekStartDay"] = weekStartPicker.value as? String ?? ""
        Self.cachedPreferences["dateFormat"] = dateFormatPicker.value as? String ?? ""
        Self.cachedPreferences["timeFormat"] = timeFormatPicker.value as? String ?? ""
        Self.cachedPreferences["timeZone"] = timeZonePicker.value as? String ?? ""
        Self.cachedPreferences["tankCapacity"] = tankCapacityField.value as? String ?? ""
        Self.cachedPreferences["gasPrice"] = gasPriceField.value as? String ?? ""
        Self.cachedPreferences["mileageRate"] = mileageRateField.value as? String ?? ""
        Self.cachedPreferences["tipDeductionEnabled"] = tipToggle.value as? String ?? ""
        Self.cachedPreferences["taxRate"] = taxRateField.value as? String ?? ""

        debugMessage("✅ Loaded preferences:")
        for (key, value) in Self.cachedPreferences.sorted(by: { $0.key < $1.key }) {
            debugMessage("  \(key) = '\(value)'")
        }

        // Close Preferences view
        let preferencesDoneButton = app.buttons["preferences_done_button"]
        if preferencesDoneButton.waitForExistence(timeout: 1) {
            waitAndTap(preferencesDoneButton)
        }

        // Close Main Menu view
        let mainMenuDoneButton = app.buttons["main_menu_done_button"]
        if mainMenuDoneButton.waitForExistence(timeout: 1) {
            waitAndTap(mainMenuDoneButton)
        }
    }

    // MARK: - Test Operation Alerts

    /// Show a test operation alert in the app UI
    /// Waits for user to see the message, then dismisses it
    @MainActor
    func showOperationAlert(_ message: String, in app: XCUIApplication) {
        // Wait for and dismiss the operation alert
        let alert = app.alerts["UI Test Operation"].firstMatch
        if alert.waitForExistence(timeout: 3) {
            debugMessage("🔔 Operation alert displayed: \(message)")
            // Wait 3 seconds for user to see the message
            Thread.sleep(forTimeInterval: 3.0)

            // Dismiss the alert by tapping OK button
            let okButton = alert.buttons["OK"]
            if okButton.exists {
                okButton.tap()
                debugMessage("Operation alert dismissed")
            }
        }
    }

    // MARK: - Debug Utilities

    /// Global debug printing utility - only outputs when debug flags are set
    func debugMessage(_ message: String, function: String = #function, file: String = #file) {
        let debugEnabled = ProcessInfo.processInfo.environment["DEBUG"] != nil ||
                          ProcessInfo.processInfo.arguments.contains("-debug")

        if debugEnabled {
            let fileName = (file as NSString).lastPathComponent
            print("DEBUG [\(fileName):\(function)]: \(message)")
        }
    }

    /// Visual verification pause - only pauses when visual debug flags are set
    func visualDebugPause(_ seconds: UInt32 = 2, function: String = #function, file: String = #file) {
        let visualDebugEnabled = ProcessInfo.processInfo.environment["VISUAL_DEBUG"] != nil ||
                                ProcessInfo.processInfo.arguments.contains("-visual-debug")
        if visualDebugEnabled {
            let fileName = (file as NSString).lastPathComponent
            print("DEBUG [\(fileName):\(function)]: ⏸️ PAUSING FOR \(seconds) SECONDS -  Consider taking screenshot.")
            sleep(seconds)
            print("DEBUG [\(fileName):\(function)]: ⏸️ PAUSE COMPLETE - Continuing test")
        }
    }

    /// Capture and attach a screenshot with a descriptive name
    /// The screenshot name will be: testName_description (e.g., "testExpenseFormValidation_before_empty_description")
    @MainActor
    func captureScreenshot(named description: String, in app: XCUIApplication, function: String = #function) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        // Extract test function name (remove parentheses and parameters)
        let testName = function.components(separatedBy: "(").first ?? function
        attachment.name = "\(testName)_\(description)"
        attachment.lifetime = .keepAlways
        add(attachment)
        debugMessage("📸 Screenshot captured: \(attachment.name ?? "unknown")")
    }

    /// Get the actual field value, accounting for placeholder text
    /// Returns nil if the field is empty (showing only placeholder)
    /// Workaround for XCTest behavior since Xcode 9 where `value` returns placeholderValue when field is empty
    @MainActor
    func fieldValue(_ textField: XCUIElement) -> String? {
        let value = textField.value as? String ?? ""
        let placeholder = textField.placeholderValue ?? ""

        // If value equals placeholder, the field is actually empty (XCTest quirk)
        if value == placeholder {
            return nil
        }

        // If value is empty, field is empty
        if value.isEmpty {
            return nil
        }

        return value
    }

    // MARK: - App Launch and Configuration

    /// Configure XCUIApplication with proper test arguments and launch
    @MainActor
    func launchApp(testName: String = #function) -> XCUIApplication {
        debugMessage("Launching app...")
        let app = XCUIApplication()

        // Pass test name to app so it can display it
        let cleanName = testName.components(separatedBy: "(").first ?? testName
        app.launchArguments.append("-testName")
        app.launchArguments.append(cleanName)

        configureTestApp(app)
        app.launch()
        debugMessage("App launched successfully")

        // Wait for and dismiss the test name alert
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 3) {
            debugMessage("🔔 Test name alert displayed: \(cleanName)")
            // Wait 3 seconds for user to see the test name
            Thread.sleep(forTimeInterval: 3.0)

            // Dismiss the alert by tapping OK button
            let okButton = alert.buttons["OK"]
            if okButton.exists {
                okButton.tap()
                debugMessage("Test name alert dismissed")
            }
        }

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
        debugMessage("Navigate to tab: \(tabName)")
        let tabButton = app.tabBars.buttons[tabName]
        XCTAssertTrue(tabButton.waitForExistence(timeout: 5), "Tab '\(tabName)' should exist")
        // Use waitAndTap for more robust tapping with fallback handling
        waitAndTap(tabButton)
    }

    /// Navigate to settings/main menu
    @MainActor
    func navigateToSettings(in app: XCUIApplication) {
        debugMessage("Attempting to navigate to settings...")

        let gearButton = findButton(keyword: "settings_button", keyword2: "Settings", keyword3: "gearshape", in: app)
        XCTAssertTrue(gearButton.exists, "Settings gear button should exist")
        waitAndTap(gearButton)
        debugMessage("Settings navigation completed")
    }

    // MARK: - UI Element Helpers

    /// Helper function to reliably find a button by keyword with proper error handling
    /// Supports multiple fallback keywords for better test resilience
    @MainActor
    func findButton(keyword: String, keyword2: String? = nil, keyword3: String? = nil, in app: XCUIApplication) -> XCUIElement {
        let keywords = [keyword, keyword2, keyword3].compactMap { $0 }
        debugMessage("Searching for button with keywords: \(keywords)")

        // Try each keyword in order
        for currentKeyword in keywords {
            let theButton = app.buttons[currentKeyword]
            if theButton.exists {
                debugMessage("✅ Direct match found for '\(currentKeyword)': identifier='\(theButton.identifier)', label='\(theButton.label)', isEnabled=\(theButton.isEnabled)")
                return theButton
            }
        }

        debugMessage("❌ No direct matches for any keywords, trying fallback search...")

        // Fallback: look for any keyword in identifier or label
        for currentKeyword in keywords {
            let matchingButtons = app.buttons.matching(NSPredicate(format: "identifier CONTAINS %@ OR label CONTAINS %@", currentKeyword, currentKeyword))
            debugMessage("Fallback search for '\(currentKeyword)' found \(matchingButtons.count) potential matches")

            if matchingButtons.count > 0 {
                // Check for multiple matches and provide helpful error message
                if matchingButtons.count > 1 {
                    debugMessage("WARNING: Found \(matchingButtons.count) buttons matching '\(currentKeyword)'. Consider adding unique accessibility labels.")
                    for i in 0..<matchingButtons.count {
                        let button = matchingButtons.element(boundBy: i)
                        debugMessage("  Button \(i): identifier='\(button.identifier)', label='\(button.label)', exists=\(button.exists), isEnabled=\(button.isEnabled)")
                    }
                } else {
                    let button = matchingButtons.firstMatch
                    debugMessage("Single fallback match for '\(currentKeyword)': identifier='\(button.identifier)', label='\(button.label)', exists=\(button.exists), isEnabled=\(button.isEnabled)")
                }

                let firstMatch = matchingButtons.firstMatch
                if firstMatch.exists {
                    debugMessage("✅ Returning fallback match for '\(currentKeyword)': exists=\(firstMatch.exists), isEnabled=\(firstMatch.isEnabled)")
                    return firstMatch
                }
            }
        }

        // No matches found for any keyword
        debugMessage("❌ CRITICAL: No button found for any keywords \(keywords) - returning non-existent element!")
        debugMessage("ALL AVAILABLE BUTTONS with full debugDescription:")
        // Iterate through all buttons and print their labels or identifiers
        for button in app.buttons.allElementsBoundByIndex.prefix(10) {
            debugMessage("\(button.debugDescription)")
        }
        XCTFail("Failed to find button with keywords \(keywords). No matches found.")

        return app.buttons[keyword] // Return the first keyword's element (non-existent)
    }

    /// Helper function to reliably find a text field by keyword with flexible discovery patterns
    @MainActor
    func findTextField(keyword: String, in app: XCUIApplication) -> XCUIElement {
        debugMessage("Searching for text field with keyword: '\(keyword)'")

        // Try direct identifier match first
        let directField = app.textFields[keyword]
        if directField.exists {
            debugMessage("✅ Direct match found: identifier='\(directField.identifier)', placeholder='\(directField.placeholderValue ?? "nil")', isEnabled=\(directField.isEnabled)")
            return directField
        }

        debugMessage("❌ No direct match for '\(keyword)', trying flexible search...")

        // Fallback 1: Search by placeholder text (case-insensitive)
        let placeholderFields = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS[c] %@", keyword))
        debugMessage("Placeholder search found \(placeholderFields.count) potential matches")

        if placeholderFields.count > 0 {
            let field = placeholderFields.firstMatch
            debugMessage("✅ Placeholder match: placeholder='\(field.placeholderValue ?? "nil")', exists=\(field.exists), isEnabled=\(field.isEnabled)")
            return field
        }

        // Fallback 2: Search by accessibility label (case-insensitive)
        let labelFields = app.textFields.matching(NSPredicate(format: "label CONTAINS[c] %@", keyword))
        debugMessage("Label search found \(labelFields.count) potential matches")

        if labelFields.count > 0 {
            let field = labelFields.firstMatch
            debugMessage("✅ Label match: label='\(field.label)', exists=\(field.exists), isEnabled=\(field.isEnabled)")
            return field
        }

        // Fallback 3: Search by identifier containing keyword (case-insensitive)
        let identifierFields = app.textFields.matching(NSPredicate(format: "identifier CONTAINS[c] %@", keyword))
        debugMessage("Identifier search found \(identifierFields.count) potential matches")

        if identifierFields.count > 0 {
            let field = identifierFields.firstMatch
            debugMessage("✅ Identifier match: identifier='\(field.identifier)', exists=\(field.exists), isEnabled=\(field.isEnabled)")
            return field
        }

        // Debug fallback: Show all available text fields for troubleshooting
        debugMessage("❌ CRITICAL: No text field found for keyword '\(keyword)' - showing all available text fields:")
        for (index, field) in app.textFields.allElementsBoundByIndex.prefix(10).enumerated() {
            debugMessage("  TextField[\(index)]: identifier='\(field.identifier)', placeholder='\(field.placeholderValue ?? "nil")', label='\(field.label)', exists=\(field.exists)")
        }

        // Return first available text field as last resort
        let firstField = app.textFields.firstMatch
        debugMessage("⚠️ Returning first available text field as fallback: exists=\(firstField.exists)")
        return firstField
    }

    /// Enter text in field and properly complete input (includes Done button tap)
    /// This is the recommended way to enter text to ensure validation triggers
    /// Automatically clears existing text before entering new text
    @MainActor
    func enterText(_ text: String, in textField: XCUIElement, app: XCUIApplication) {
        debugMessage("Entering text '\(text)' into field: identifier='\(textField.identifier)', label='\(textField.label)'")
        debugMessage("Field state before tap: exists=\(textField.exists), isEnabled=\(textField.isEnabled), isFocused=\(textField.hasFocus)")

        waitAndTap(textField)
        textField.clearText()
        
        textField.typeText(text)
        debugMessage("Text typed. Field value after typing: '\(textField.value ?? "nil")'")

        // CRITICAL: Always tap Done button to trigger validation and calculations
        let doneButton = app.buttons["Done"]
        if doneButton.exists {
            debugMessage("✅ Done button found, tapping to trigger validation...")
            doneButton.tap()
            debugMessage("Done button tapped successfully")
        } else {
            debugMessage("❌ WARNING: Done button not found! Validation may not trigger.")
            debugMessage("Available keyboard buttons:")
            let keyboardButtons = app.keyboards.buttons.allElementsBoundByIndex.prefix(5)
            for (index, button) in keyboardButtons.enumerated() {
                debugMessage("  Keyboard[\(index)]: identifier='\(button.identifier)', label='\(button.label)'")
            }
        }

        debugMessage("Dismissing keyboard if present...")
        dismissKeyboardIfPresent(in: app)

        let keyboardCount = app.keyboards.count
        debugMessage("Keyboard dismissal complete. Keyboards remaining: \(keyboardCount)")

        // Brief pause to allow field value to update after keyboard dismissal
        Thread.sleep(forTimeInterval: 0.3)

        // Verify field value matches expected text (accounting for formatting and placeholders)
        let actualValue = fieldValue(textField) ?? ""
        debugMessage("Final field value: '\(actualValue)' (expected: '\(text)')")

        // Try numeric comparison first (strips formatting like "$" and ",")
        let cleanActualValue = actualValue.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
        let cleanExpectedValue = text.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)

        // If both can be parsed as numbers, use numeric comparison
        if let actualDouble = Double(cleanActualValue), let expectedDouble = Double(cleanExpectedValue) {
            XCTAssertEqual(actualDouble, expectedDouble, accuracy: 0.001, "Field value '\(actualValue)' does not match expected '\(text)' (numeric comparison). Field identifier: '\(textField.identifier)'")
            debugMessage("✅ Field value verified: '\(actualValue)' matches expected '\(text)' (numeric)")
        } else {
            // Otherwise use string comparison
            XCTAssertEqual(actualValue, text, "Field value '\(actualValue)' does not match expected '\(text)'. Field identifier: '\(textField.identifier)'")
            debugMessage("✅ Field value verified: '\(actualValue)' matches expected '\(text)' (string)")
        }
    }

    /// Dismiss keyboard if present
    @MainActor
    func dismissKeyboardIfPresent(in app: XCUIApplication) {
        let keyboardCount = app.keyboards.count
        debugMessage("Keyboard dismissal attempt: \(keyboardCount) keyboards present")
        if keyboardCount > 0 {
            debugMessage("Tapping outside text fields to dismiss keyboard...")
            // Try tapping outside text fields to dismiss keyboard
            let coordinate = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
            coordinate.tap()
            debugMessage("Coordinate tap completed")
        } else {
            debugMessage("No keyboards to dismiss")
        }
    }

    /// Wait for element and tap with timeout, handling scroll failures gracefully
    @MainActor
    func waitAndTap(_ element: XCUIElement, timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        debugMessage("Waiting for element to exist: identifier='\(element.identifier)', label='\(element.label)', timeout=\(timeout)s")
        let exists = element.waitForExistence(timeout: timeout)

        if exists {
            debugMessage("✅ Element exists: isEnabled=\(element.isEnabled), isHittable=\(element.isHittable)")

            // Check if element is hittable before attempting to tap
            if element.isHittable {
                debugMessage("Element is hittable, performing standard tap")
                element.tap()
                debugMessage("Element tap completed successfully")
            } else {
                debugMessage("⚠️ Element not hittable (likely off-screen), trying coordinate tap...")
                // Try tapping at the element's center coordinate directly
                let coordinate = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                coordinate.tap()
                debugMessage("Coordinate tap completed")

                // Brief pause to allow tap to register
                Thread.sleep(forTimeInterval: 0.5)
            }
        } else {
            debugMessage("❌ TIMEOUT: Element did not appear within \(timeout) seconds")
        }
        XCTAssertTrue(exists, "Element should exist within \(timeout) seconds", file: file, line: line)
    }

    // MARK: - Date/Time Format Helpers

    /// Infer date format string from a placeholder example
    /// Matches formats from PreferencesView.swift:
    /// - "M/d/yyyy" (US Format)
    /// - "MMM d, yyyy" (Written Format)
    /// - "d/M/yyyy" (International Format)
    /// - "yyyy-MM-dd" (ISO Format)
    ///
    /// - Parameter placeholder: Example date string showing today's date
    /// - Returns: DateFormatter format string
    func inferDateFormat(from placeholder: String) -> String {
        if placeholder.contains("-") {
            // ISO Format: "2025-10-10"
            return "yyyy-MM-dd"
        } else if placeholder.contains(",") {
            // Written Format: "Oct 10, 2025" or "Jan 1, 2025"
            return "MMM d, yyyy"
        } else if placeholder.contains("/") {
            // Could be US (M/d/yyyy) or International (d/M/yyyy)
            // Placeholder shows today's date, so use current date to determine format
            let today = Date()
            let calendar = Calendar.current
            let currentMonth = calendar.component(.month, from: today)
            let currentDay = calendar.component(.day, from: today)

            // Split the placeholder (e.g., "10/10/2025" -> ["10", "10", "2025"])
            let components = placeholder.split(separator: "/").compactMap { Int($0) }
            guard components.count >= 2 else {
                return "M/d/yyyy" // Fallback
            }

            let firstNum = components[0]
            let secondNum = components[1]

            if currentMonth != currentDay {
                // Easy case: month and day are different
                if firstNum == currentMonth {
                    return "M/d/yyyy" // US Format (month first)
                } else if secondNum == currentMonth {
                    return "d/M/yyyy" // International Format (day first)
                }
            } else {
                // Edge case: month == day (e.g., Oct 10 = 10/10)
                // Use current month as tie-breaker: which position has the current month number?
                if firstNum == currentMonth {
                    return "M/d/yyyy" // Assume US Format
                } else if secondNum == currentMonth {
                    return "d/M/yyyy" // Assume International Format
                }
            }

            // Fallback to US format
            return "M/d/yyyy"
        }

        // Fallback to US format
        return "M/d/yyyy"
    }

    /// Infer time format string from a placeholder example
    func inferTimeFormat(from placeholder: String) -> String {
        if placeholder.uppercased().contains("AM") || placeholder.uppercased().contains("PM") {
            // 12-hour format: "6:30 PM"
            return "h:mm a"
        } else {
            // 24-hour format: "18:30"
            return "HH:mm"
        }
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

        debugMessage("Starting test: \(name)")
    }

    override func tearDownWithError() throws {
        debugMessage("Completed test: \(name)")
    }
}
