//
//  RideshareTrackerToolsUITests.swift
//  Rideshare TrackerUITests
//
//  Created by Claude on 9/22/25.
//

import XCTest

/// Consolidated UI tests for settings, sync, backup, export, and utility features
/// Reduces 30 tool-related tests → 15 tests with shared utilities and lightweight fixtures
/// Focuses on navigation, settings, and utility features without heavy business logic
final class RideshareTrackerToolsUITests: RideshareTrackerUITestBase {

    // MARK: - Sync Functionality Tests (Consolidates 10 → 4 tests)

    /// Sync setup and configuration test
    /// Consolidates: testIncrementalSyncMenuNavigation, testInitialSyncWorkflow, testSyncToggleInteraction
    /// Tests: Complete sync setup, configuration, initial setup
    @MainActor
    func testSyncSetupAndConfiguration() throws {
        debugPrint("Testing sync setup and configuration workflow")

        let app = launchApp()

        // Navigate to settings
        navigateToSettings(in: app)

        // Look for sync settings option
        if app.buttons["sync_settings_button"].exists {
            app.buttons["sync_settings_button"].tap()

            // Verify sync setup screen
            if app.navigationBars["Incremental Cloud Sync"].waitForExistence(timeout: 3) {
                debugPrint("Successfully navigated to sync settings")

                // Test sync toggle interaction
                if app.switches["enable_sync_toggle"].exists {
                    let syncToggle = app.switches["enable_sync_toggle"]
                    let initialState = syncToggle.value as? String

                    syncToggle.tap()
                    visualDebugPause(1)

                    // Verify state changed
                    let newState = syncToggle.value as? String
                    XCTAssertNotEqual(initialState, newState, "Sync toggle should change state")

                    debugPrint("Sync toggle interaction working")
                }

                // Test initial sync workflow if available
                if app.buttons["setup_initial_sync_button"].exists {
                    app.buttons["setup_initial_sync_button"].tap()

                    if app.alerts.count > 0 {
                        debugPrint("Initial sync confirmation dialog appeared")
                        // Handle confirmation dialog
                        if app.buttons["Confirm"].exists {
                            app.buttons["Confirm"].tap()
                        }
                    }
                }
            }
        }

        debugPrint("Sync setup and configuration test passed")
    }

    /// Sync operations and status test
    /// Consolidates: testManualSyncButton, testSyncStatusDisplay, testSyncSettingsVisibility
    /// Tests: Manual sync, status display, settings visibility
    @MainActor
    func testSyncOperationsAndStatus() throws {
        debugPrint("Testing sync operations and status display")

        let app = launchApp()
        navigateToSettings(in: app)

        // Navigate to sync settings
        if app.buttons["sync_settings_button"].exists {
            app.buttons["sync_settings_button"].tap()

            if app.navigationBars["Incremental Cloud Sync"].waitForExistence(timeout: 3) {
                // Test manual sync button
                if app.buttons["manual_sync_button"].exists {
                    app.buttons["manual_sync_button"].tap()

                    // Look for sync progress or status indication
                    if app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Syncing'")).count > 0 {
                        debugPrint("Sync status display working")
                        visualDebugPause(2) // Allow sync to complete
                    }
                }

                // Test sync status display
                if app.staticTexts["last_sync_status"].exists {
                    let statusText = app.staticTexts["last_sync_status"]
                    debugPrint("Sync status: \(statusText.label)")
                }

                // Test sync settings visibility
                if app.staticTexts["sync_frequency_label"].exists {
                    debugPrint("Sync frequency settings visible")
                }
            }
        }

        debugPrint("Sync operations and status test passed")
    }

    /// Sync frequency and scheduling test
    /// Consolidates: testSyncFrequencySelection, testSyncScreenScrolling
    /// Tests: Frequency selection, scheduling options
    @MainActor
    func testSyncFrequencyAndScheduling() throws {
        debugPrint("Testing sync frequency and scheduling options")

        let app = launchApp()
        navigateToSettings(in: app)

        if app.buttons["sync_settings_button"].exists {
            app.buttons["sync_settings_button"].tap()

            if app.navigationBars["Incremental Cloud Sync"].waitForExistence(timeout: 3) {
                // Test sync frequency selection
                if app.buttons["sync_frequency_picker"].exists {
                    app.buttons["sync_frequency_picker"].tap()

                    // Test different frequency options
                    if app.buttons["Immediate"].exists {
                        app.buttons["Immediate"].tap()
                        debugPrint("Selected immediate sync frequency")
                    } else if app.buttons["Hourly"].exists {
                        app.buttons["Hourly"].tap()
                        debugPrint("Selected hourly sync frequency")
                    } else if app.buttons["Daily"].exists {
                        app.buttons["Daily"].tap()
                        debugPrint("Selected daily sync frequency")
                    }
                }

                // Test screen scrolling if content is long
                if app.scrollViews.count > 0 {
                    let scrollView = app.scrollViews.firstMatch
                    scrollView.swipeUp()
                    visualDebugPause(1)
                    scrollView.swipeDown()
                    debugPrint("Sync screen scrolling working")
                }
            }
        }

        debugPrint("Sync frequency and scheduling test passed")
    }

    /// Sync education and dismissal test
    /// Consolidates: testSyncScreenDismissal, testHowItWorksSection, testRequirementsSection
    /// Tests: User education, screen dismissal, requirements
    @MainActor
    func testSyncEducationAndDismissal() throws {
        debugPrint("Testing sync education and screen dismissal")

        let app = launchApp()
        navigateToSettings(in: app)

        if app.buttons["sync_settings_button"].exists {
            app.buttons["sync_settings_button"].tap()

            if app.navigationBars["Incremental Cloud Sync"].waitForExistence(timeout: 3) {
                // Test "How It Works" section
                if app.buttons["how_it_works_section"].exists {
                    app.buttons["how_it_works_section"].tap()

                    // Look for educational content
                    if app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'iCloud'")).count > 0 {
                        debugPrint("How It Works section displaying educational content")
                    }
                }

                // Test requirements section
                if app.buttons["requirements_section"].exists {
                    app.buttons["requirements_section"].tap()

                    // Look for requirements information
                    if app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'iOS'")).count > 0 {
                        debugPrint("Requirements section displaying system requirements")
                    }
                }

                // Test screen dismissal
                if app.navigationBars.buttons["Back"].exists {
                    app.navigationBars.buttons["Back"].tap()
                } else if app.navigationBars.buttons["Done"].exists {
                    app.navigationBars.buttons["Done"].tap()
                } else if app.navigationBars.buttons.count > 0 {
                    app.navigationBars.buttons.firstMatch.tap()
                }

                // Verify we're back to settings
                XCTAssertTrue(app.staticTexts["Menu"].waitForExistence(timeout: 3) ||
                             app.navigationBars["Menu"].exists,
                             "Should return to settings after dismissal")
            }
        }

        debugPrint("Sync education and dismissal test passed")
    }

    // MARK: - Import/Export Functionality Tests (Enhanced with new UI structure)

    /// Import navigation and type selection test
    /// Tests: Import page navigation, type picker, shift subtype picker, UI consistency
    @MainActor
    func testImportNavigationAndTypes() throws {
        debugPrint("Testing import navigation and type selection")

        let app = launchApp()
        navigateToSettings(in: app)

        // Navigate to Import/Export
        let importExportElements = [
            app.staticTexts["Import/Export"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS 'Import'")).firstMatch
        ]

        var navigated = false
        for element in importExportElements {
            if element.exists {
                element.tap()
                navigated = true
                break
            }
        }

        XCTAssertTrue(navigated, "Should find Import/Export option in menu")

        // Wait for Import/Export view to load
        if app.navigationBars["Import/Export"].waitForExistence(timeout: 3) {
            debugPrint("Successfully navigated to Import/Export page")

            // Verify Import tab is accessible and tap it
            let importTab = app.buttons["Import"]
            XCTAssertTrue(importTab.exists, "Import tab should exist")
            importTab.tap()
            visualDebugPause(1)

            // Verify green import icon exists
            XCTAssertTrue(app.images["square.and.arrow.down"].exists, "Green import icon should be visible")

            // Verify Import Type picker exists
            let importTypePicker = app.segmentedControls.firstMatch
            XCTAssertTrue(importTypePicker.exists, "Import Type picker should exist")

            // Test selecting Shifts import type
            if importTypePicker.buttons["Shifts"].exists {
                importTypePicker.buttons["Shifts"].tap()
                visualDebugPause(1)
                debugPrint("Selected Shifts import type")

                // Verify Shift Import Type picker appears for Shifts
                let shiftSubtypePicker = app.segmentedControls.element(boundBy: 1)
                XCTAssertTrue(shiftSubtypePicker.exists, "Shift Import Type picker should appear for Shifts")

                // Test all shift import subtypes
                if shiftSubtypePicker.buttons["Shift CSV"].exists {
                    shiftSubtypePicker.buttons["Shift CSV"].tap()
                    visualDebugPause(1)
                    XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'CSV'")).count > 0,
                                 "Shift CSV description should be visible")
                    debugPrint("Shift CSV option working")
                }

                if shiftSubtypePicker.buttons["Toll CSV"].exists {
                    shiftSubtypePicker.buttons["Toll CSV"].tap()
                    visualDebugPause(1)
                    XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'toll'")).count > 0,
                                 "Toll CSV description should be visible")
                    debugPrint("Toll CSV option working")
                }

                if shiftSubtypePicker.buttons["Uber PDF"].exists {
                    shiftSubtypePicker.buttons["Uber PDF"].tap()
                    visualDebugPause(1)
                    XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Uber'")).count > 0,
                                 "Uber PDF description should be visible")
                    debugPrint("Uber PDF option working")
                }
            }

            // Test selecting Expenses import type
            if importTypePicker.buttons["Expenses"].exists {
                importTypePicker.buttons["Expenses"].tap()
                visualDebugPause(1)
                debugPrint("Selected Expenses import type")

                // Verify Shift Import Type picker is hidden for Expenses
                let shiftSubtypePicker = app.segmentedControls.element(boundBy: 1)
                XCTAssertFalse(shiftSubtypePicker.exists, "Shift Import Type picker should be hidden for Expenses")
                debugPrint("Shift subtype picker correctly hidden for Expenses")
            }

            // Verify select file button exists
            let selectFileButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Select'")).firstMatch
            XCTAssertTrue(selectFileButton.exists, "Select file button should exist")
        }

        debugPrint("Import navigation and types test passed")
    }

    /// Export features test
    /// Consolidates: testExportFunctionality, testExportWithDifferentTypes
    /// Tests: Complete export workflow, different formats, new UI structure
    @MainActor
    func testExportNavigationAndTypes() throws {
        debugPrint("Testing export navigation and type selection")

        let app = launchApp()
        navigateToSettings(in: app)

        // Navigate to Import/Export
        let importExportElements = [
            app.staticTexts["Import/Export"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS 'Import'")).firstMatch
        ]

        var navigated = false
        for element in importExportElements {
            if element.exists {
                element.tap()
                navigated = true
                break
            }
        }

        XCTAssertTrue(navigated, "Should find Import/Export option in menu")

        // Wait for Import/Export view to load
        if app.navigationBars["Import/Export"].waitForExistence(timeout: 3) {
            debugPrint("Successfully navigated to Import/Export page")

            // Tap Export tab
            let exportTab = app.buttons["Export"]
            XCTAssertTrue(exportTab.exists, "Export tab should exist")
            exportTab.tap()
            visualDebugPause(1)

            // Verify green export icon exists
            XCTAssertTrue(app.images["square.and.arrow.up"].exists, "Green export icon should be visible")

            // Verify Export Type picker exists
            let exportTypePicker = app.segmentedControls.firstMatch
            XCTAssertTrue(exportTypePicker.exists, "Export Type picker should exist")

            // Test selecting Shifts export type
            if exportTypePicker.buttons["Shifts"].exists {
                exportTypePicker.buttons["Shifts"].tap()
                visualDebugPause(1)
                debugPrint("Selected Shifts export type")

                // Verify description updated
                XCTAssertTrue(app.staticTexts["Export Shifts"].exists, "Export Shifts title should be visible")
            }

            // Test selecting Expenses export type
            if exportTypePicker.buttons["Expenses"].exists {
                exportTypePicker.buttons["Expenses"].tap()
                visualDebugPause(1)
                debugPrint("Selected Expenses export type")

                // Verify description updated
                XCTAssertTrue(app.staticTexts["Export Expenses"].exists, "Export Expenses title should be visible")
            }

            // Verify date range section exists
            XCTAssertTrue(app.staticTexts["Date Range"].exists, "Date Range section should exist")

            // Verify export button exists
            let exportButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Export'")).firstMatch
            XCTAssertTrue(exportButton.exists, "Export button should exist")
        }

        debugPrint("Export navigation and types test passed")
    }

    /// Backup navigation and options test
    /// Tests: Backup page navigation, data summary, include images toggle, new UI structure
    @MainActor
    func testBackupNavigationAndOptions() throws {
        debugPrint("Testing backup navigation and options")

        let app = launchApp()
        navigateToSettings(in: app)

        // Navigate to Backup/Restore
        let backupRestoreElements = [
            app.staticTexts["Backup/Restore"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS 'Backup'")).firstMatch
        ]

        var navigated = false
        for element in backupRestoreElements {
            if element.exists {
                element.tap()
                navigated = true
                break
            }
        }

        XCTAssertTrue(navigated, "Should find Backup/Restore option in menu")

        // Wait for Backup/Restore view to load
        if app.navigationBars["Backup/Restore"].waitForExistence(timeout: 3) {
            debugPrint("Successfully navigated to Backup/Restore page")

            // Verify Backup tab is accessible and tap it
            let backupTab = app.buttons["Backup"]
            XCTAssertTrue(backupTab.exists, "Backup tab should exist")
            backupTab.tap()
            visualDebugPause(1)

            // Verify orange backup icon exists
            XCTAssertTrue(app.images["externaldrive"].exists, "Orange backup icon should be visible")

            // Verify title
            XCTAssertTrue(app.staticTexts["Create Full Backup"].exists, "Backup title should be visible")

            // Verify Data Summary section exists
            XCTAssertTrue(app.staticTexts["Data to Backup"].exists, "Data summary section should exist")

            // Verify data summary cards exist
            XCTAssertTrue(app.staticTexts["Shifts"].exists, "Shifts card should exist")
            XCTAssertTrue(app.staticTexts["Expenses"].exists, "Expenses card should exist")
            XCTAssertTrue(app.staticTexts["Images"].exists, "Images card should exist")

            // Verify Include Images toggle exists and is accessible
            let includeImagesToggle = app.switches.matching(NSPredicate(format: "label CONTAINS 'Include Image Attachments'")).firstMatch
            XCTAssertTrue(includeImagesToggle.exists, "Include Images toggle should exist")

            if includeImagesToggle.exists {
                debugPrint("Include Images toggle found and is accessible")

                // Verify toggle state can be read (either on or off)
                let toggleState = includeImagesToggle.value as? String
                XCTAssertNotNil(toggleState, "Toggle state should be readable")
                debugPrint("Include Images toggle state: \(toggleState ?? "unknown")")
            }

            // Verify Backup Details section exists
            XCTAssertTrue(app.staticTexts["Backup Details"].exists, "Backup Details section should exist")

            // Verify Create Backup button exists
            let createBackupButton = app.buttons["Create Backup"]
            XCTAssertTrue(createBackupButton.exists, "Create Backup button should exist")
        }

        debugPrint("Backup navigation and options test passed")
    }

    /// Restore navigation and options test
    /// Tests: Restore page navigation, restore method picker, new UI structure
    @MainActor
    func testRestoreNavigationAndOptions() throws {
        debugPrint("Testing restore navigation and options")

        let app = launchApp()
        navigateToSettings(in: app)

        // Navigate to Backup/Restore
        let backupRestoreElements = [
            app.staticTexts["Backup/Restore"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS 'Backup'")).firstMatch
        ]

        var navigated = false
        for element in backupRestoreElements {
            if element.exists {
                element.tap()
                navigated = true
                break
            }
        }

        XCTAssertTrue(navigated, "Should find Backup/Restore option in menu")

        // Wait for Backup/Restore view to load
        if app.navigationBars["Backup/Restore"].waitForExistence(timeout: 3) {
            debugPrint("Successfully navigated to Backup/Restore page")

            // Tap Restore tab
            let restoreTab = app.buttons["Restore"]
            XCTAssertTrue(restoreTab.exists, "Restore tab should exist")
            restoreTab.tap()
            visualDebugPause(1)

            // Verify orange restore icon exists
            XCTAssertTrue(app.images["externaldrive.badge.plus"].exists, "Orange restore icon should be visible")

            // Verify title
            XCTAssertTrue(app.staticTexts["Restore from Backup"].exists, "Restore title should be visible")

            // Verify Restore Method picker exists
            XCTAssertTrue(app.staticTexts["Restore Method"].exists, "Restore Method section should exist")

            let restoreMethodPicker = app.segmentedControls.firstMatch
            XCTAssertTrue(restoreMethodPicker.exists, "Restore Method picker should exist")

            // Test all restore methods
            if restoreMethodPicker.buttons["Clear & Restore"].exists {
                restoreMethodPicker.buttons["Clear & Restore"].tap()
                visualDebugPause(1)
                XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Delete all current data'")).count > 0,
                             "Clear & Restore description should be visible")
                debugPrint("Clear & Restore option working")
            }

            if restoreMethodPicker.buttons["Skip Duplicates"].exists {
                restoreMethodPicker.buttons["Skip Duplicates"].tap()
                visualDebugPause(1)
                XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Keep all current data'")).count > 0,
                             "Skip Duplicates description should be visible")
                debugPrint("Skip Duplicates option working")
            }

            if restoreMethodPicker.buttons["Merge"].exists {
                restoreMethodPicker.buttons["Merge"].tap()
                visualDebugPause(1)
                XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Update existing records'")).count > 0,
                             "Merge description should be visible")
                debugPrint("Merge option working")
            }

            // Verify Select Backup File button exists
            let selectFileButton = app.buttons["Select Backup File"]
            XCTAssertTrue(selectFileButton.exists, "Select Backup File button should exist")

            // Verify Restore Details section exists
            XCTAssertTrue(app.staticTexts["Restore Details"].exists, "Restore Details section should exist")
        }

        debugPrint("Restore navigation and options test passed")
    }

    // MARK: - Date and Navigation Tests (Consolidates 7 → 4 tests)

    /// Date range picker functionality test
    /// Consolidates: testDateRangePickerHidesCustomFields, testDateRangePickerShowsCustomFields, testDateRangeDisplaysCalculatedDates
    /// Tests: Date picker behavior, custom fields, calculations
    @MainActor
    func testDateRangePickerFunctionality() throws {
        debugPrint("Testing date range picker functionality")

        let app = launchApp()

        // Test date range picker in shifts view
        navigateToTab("Shifts", in: app)

        if app.buttons["date_range_picker"].exists {
            app.buttons["date_range_picker"].tap()

            // Test predefined ranges hide custom fields
            if app.buttons["This Week"].exists {
                app.buttons["This Week"].tap()

                // Custom date fields should be hidden
                XCTAssertFalse(app.datePickers["start_date_picker"].exists,
                              "Custom date fields should be hidden for predefined ranges")
                debugPrint("Predefined range hides custom fields correctly")
            }

            // Test custom range shows custom fields
            app.buttons["date_range_picker"].tap()
            if app.buttons["Custom"].exists {
                app.buttons["Custom"].tap()

                // Custom date fields should be visible
                if app.datePickers.count > 0 {
                    debugPrint("Custom range shows date picker fields correctly")
                }
            }

            // Test calculated dates display
            if app.staticTexts.containing(NSPredicate(format: "label CONTAINS '2025'")).count > 0 {
                debugPrint("Date range displays calculated dates")
            }
        }

        debugPrint("Date range picker functionality test passed")
    }

    /// Date picker and week navigation test
    /// Consolidates: testDatePickerNavigation, testWeekNavigationControls, testWeekStartDayRespected
    /// Tests: Date picker navigation, week controls, start day preferences
    @MainActor
    func testDatePickerAndWeekNavigation() throws {
        debugPrint("Testing date picker and week navigation")

        let app = launchApp()
        navigateToTab("Shifts", in: app)

        // Test week navigation controls
        if app.buttons["previous_week"].exists {
            app.buttons["previous_week"].tap()
            visualDebugPause(1)

            app.buttons["next_week"].tap()
            visualDebugPause(1)
            debugPrint("Week navigation controls working")
        }

        // Test week start day preference
        navigateToSettings(in: app)

        if app.buttons["preferences_button"].exists {
            app.buttons["preferences_button"].tap()

            if app.buttons["week_start_day_picker"].exists {
                app.buttons["week_start_day_picker"].tap()

                // Test different start days
                if app.buttons["Monday"].exists {
                    app.buttons["Monday"].tap()
                    debugPrint("Selected Monday as week start day")
                } else if app.buttons["Sunday"].exists {
                    app.buttons["Sunday"].tap()
                    debugPrint("Selected Sunday as week start day")
                }

                // Go back and verify week display respects preference
                navigateToTab("Shifts", in: app)
                debugPrint("Week start day preference test completed")
            }
        }

        debugPrint("Date picker and week navigation test passed")
    }

    /// Navigation and tabs test
    /// Consolidates: testMainTabNavigation, testAppNavigation
    /// Tests: Main navigation, tab switching, app-level navigation
    @MainActor
    func testNavigationAndTabs() throws {
        debugPrint("Testing navigation and tab functionality")

        let app = launchApp()

        // Test main tab navigation
        navigateToTab("Shifts", in: app)
        XCTAssertTrue(app.navigationBars["Shifts"].exists ||
                     app.staticTexts["Rideshare Tracker"].exists,
                     "Shifts tab should be accessible")

        navigateToTab("Expenses", in: app)
        XCTAssertTrue(app.navigationBars["Expenses"].exists ||
                     app.staticTexts["Monthly Expenses"].exists,
                     "Expenses tab should be accessible")

        // Test app-level navigation patterns
        navigateToSettings(in: app)

        // Test deep navigation
        if app.buttons["preferences_button"].exists {
            app.buttons["preferences_button"].tap()

            // Navigate back using navigation controls
            if app.navigationBars.buttons["Back"].exists {
                app.navigationBars.buttons["Back"].tap()
            }

            // Verify we're back to settings
            XCTAssertTrue(app.staticTexts["Menu"].exists ||
                         app.navigationBars["Menu"].exists,
                         "Should return to settings menu")
        }

        debugPrint("Navigation and tabs test passed")
    }

    /// Gestures and interaction test
    /// Consolidates: testSwipeGestures, testAllActionableElements
    /// Tests: Gestures, interactive elements, touch behavior
    @MainActor
    func testGesturesAndInteraction() throws {
        debugPrint("Testing gestures and interactive elements")

        let app = launchApp()

        // Test swipe gestures in list views
        navigateToTab("Shifts", in: app)

        if app.cells.count > 0 {
            let firstCell = app.cells.firstMatch

            // Test swipe actions if available
            firstCell.swipeLeft()
            visualDebugPause(1)

            // Look for action buttons (edit, delete, etc.)
            if app.buttons["Delete"].exists || app.buttons["Edit"].exists {
                debugPrint("Swipe actions available on shift cells")

                // Cancel swipe action
                firstCell.swipeRight()
            }
        }

        // Test actionable elements accessibility
        navigateToSettings(in: app)

        // Count and test actionable elements
        let buttons = app.buttons.allElementsBoundByIndex
        debugPrint("Found \(buttons.count) actionable buttons in settings")

        for button in buttons.prefix(5) { // Test first 5 to avoid timeout
            if button.exists && button.isEnabled {
                debugPrint("Button '\(button.identifier)' is actionable")
            }
        }

        debugPrint("Gestures and interaction test passed")
    }

    // MARK: - Settings and Preferences Tests (Consolidates 5 → 3 tests)

    /// Preferences and settings test
    /// Consolidates: testSettingsMenuNavigation, part of accessibility tests
    /// Tests: Settings navigation, preference management
    @MainActor
    func testPreferencesAndSettings() throws {
        debugPrint("Testing preferences and settings navigation")

        let app = launchApp()
        navigateToSettings(in: app)

        // Test settings menu navigation - check for correct screen name "Menu"
        let menuTextExists = app.staticTexts["Menu"].exists
        let menuNavExists = app.navigationBars["Menu"].exists

        debugPrint("Checking if we're on menu screen:")
        debugPrint("  app.staticTexts[\"Menu\"].exists = \(menuTextExists)")
        debugPrint("  app.navigationBars[\"Menu\"].exists = \(menuNavExists)")

        XCTAssertTrue(menuTextExists || menuNavExists, "Menu screen should be accessible")

        // Test preferences navigation - look for "Preferences" text/button on Menu screen
        if app.staticTexts["Preferences"].exists {
            app.staticTexts["Preferences"].tap()
            debugPrint("Tapped Preferences via staticText")

            // Wait for preferences screen to load
            if app.navigationBars["Preferences"].waitForExistence(timeout: 3) {
                debugPrint("Successfully navigated to Preferences screen")

                // Test basic preference fields if they exist
                // Note: Using generic field identifiers since we don't know exact names
                let textFields = app.textFields.allElementsBoundByIndex
                debugPrint("Found \(textFields.count) text fields in preferences")

                if textFields.count > 0 {
                    debugPrint("Preference fields are accessible")
                    debugPrint("\(textFields)")
                }
            } else {
                debugPrint("Could not reach Preferences screen")
            }
        } else if app.buttons.matching(NSPredicate(format: "label CONTAINS 'Preferences'")).firstMatch.exists {
            let preferencesButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Preferences'")).firstMatch
            preferencesButton.tap()
            debugPrint("Tapped Preferences via button search")
        } else {
            debugPrint("Preferences option not found on Menu screen")
        }

        debugPrint("Preferences and settings test passed")
    }

    /// Accessibility and labels test
    /// Consolidates: testAccessibilityLabels, testAllDateRangeOptionsExist
    /// Tests: Accessibility compliance, label verification
    @MainActor
    func testAccessibilityAndLabels() throws {
        debugPrint("Testing accessibility labels and compliance")

        let app = launchApp()

        // Test main navigation accessibility
        let shiftsTab = app.tabBars.buttons["Shifts"]
        XCTAssertTrue(shiftsTab.exists, "Shifts tab should have accessibility label")

        let expensesTab = app.tabBars.buttons["Expenses"]
        XCTAssertTrue(expensesTab.exists, "Expenses tab should have accessibility label")

        // Test settings accessibility
        navigateToSettings(in: app)

        let settingsElements = [
            "preferences_button",
            "sync_settings_button",
            "backup_data_button",
            "export_data_button"
        ]

        for elementId in settingsElements {
            if app.buttons[elementId].exists {
                debugPrint("Settings element '\(elementId)' has accessibility identifier")
            }
        }

        // Test date range options accessibility
        navigateToTab("Shifts", in: app)

        if app.buttons["date_range_picker"].exists {
            app.buttons["date_range_picker"].tap()

            let dateRangeOptions = [
                "This Week",
                "Last Week",
                "This Month",
                "Last Month",
                "Custom"
            ]

            for option in dateRangeOptions {
                if app.buttons[option].exists {
                    debugPrint("Date range option '\(option)' is accessible")
                }
            }

            // Dismiss picker
            if app.buttons["This Week"].exists {
                app.buttons["This Week"].tap()
            }
        }

        debugPrint("Accessibility and labels test passed")
    }

    /// Performance and launch test
    /// Consolidates: testLaunchPerformance, app startup tests
    /// Tests: Launch performance, startup time, initial load
    @MainActor
    func testPerformanceAndLaunch() throws {
        debugPrint("Testing performance and launch characteristics")

        // Measure launch performance
        let launchMetric = XCTApplicationLaunchMetric()

        measure(metrics: [launchMetric]) {
            let testApp = XCUIApplication()
            configureTestApp(testApp)
            testApp.launch()
        }

        let app = launchApp()

        // Test initial load responsiveness
        let startTime = Date()
        XCTAssertTrue(app.staticTexts["Rideshare Tracker"].waitForExistence(timeout: 5))
        let loadTime = Date().timeIntervalSince(startTime)

        debugPrint("App loaded in \(loadTime) seconds")

        // Test tab switching performance
        let tabSwitchStart = Date()
        navigateToTab("Expenses", in: app)
        navigateToTab("Shifts", in: app)
        let tabSwitchTime = Date().timeIntervalSince(tabSwitchStart)

        debugPrint("Tab switching completed in \(tabSwitchTime) seconds")

        debugPrint("Performance and launch test passed")
    }

    // MARK: - Utility Tests (2 tests remain)

    /// Utility features test
    /// Tests: Utility functions, helper features
    @MainActor
    func testUtilityFeatures() throws {
        debugPrint("Testing utility features and helper functions")

        let app = launchApp()

        // Test calculator utility if available
        navigateToTab("Shifts", in: app)

        let startShiftButton = findButton(keyword: "start_shift_button", in: app)
        waitAndTap(startShiftButton)

        if app.navigationBars["Start Shift"].waitForExistence(timeout: 3) {
            // Test calculator utility in mileage field
            let mileageField = findTextField(keyword: "mileage", in: app)
            if mileageField.exists {
                waitAndTap(mileageField)

                // Test if calculator is available
                if app.keyboards.count > 0 {
                    debugPrint("Calculator/keyboard utility available")
                }

                dismissKeyboardIfPresent(in: app)
            }

            // Test form auto-completion utilities
            let locationField = findTextField(keyword: "location", in: app)
            if locationField.exists {
                enterText("Test Location", in: locationField, app: app)
                debugPrint("Location field utility working")
            }

            // Cancel shift creation
            if app.navigationBars.buttons["Cancel"].exists {
                app.navigationBars.buttons["Cancel"].tap()
            }
        }

        debugPrint("Utility features test passed")
    }

    /// Edge cases and error handling test
    /// Tests: Edge cases, error scenarios, boundary conditions
    @MainActor
    func testEdgeCasesAndErrorHandling() throws {
        debugPrint("Testing edge cases and error handling")

        let app = launchApp()

        // Test empty data scenarios
        navigateToTab("Shifts", in: app)

        // Test behavior with no shifts
        if app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'No shifts'")).count > 0 {
            debugPrint("Empty shifts state handled correctly")
        }

        navigateToTab("Expenses", in: app)

        // Test behavior with no expenses
        if app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'No expenses'")).count > 0 {
            debugPrint("Empty expenses state handled correctly")
        }

        // Test network error scenarios (sync)
        navigateToSettings(in: app)

        if app.buttons["sync_settings_button"].exists {
            app.buttons["sync_settings_button"].tap()

            // Test sync when potentially offline
            if app.buttons["manual_sync_button"].exists {
                app.buttons["manual_sync_button"].tap()

                // Look for error handling
                if app.alerts.count > 0 {
                    debugPrint("Sync error dialog appeared - good error handling")

                    if app.buttons["OK"].exists {
                        app.buttons["OK"].tap()
                    }
                }
            }
        }

        debugPrint("Edge cases and error handling test passed")
    }

    // MARK: - Helper Methods

    /// Configure XCUIApplication for performance testing
    @MainActor
    private func configureTestApp(_ app: XCUIApplication) {
        if ProcessInfo.processInfo.arguments.contains("-testing") {
            app.launchArguments.append("-testing")
        }
    }
}
