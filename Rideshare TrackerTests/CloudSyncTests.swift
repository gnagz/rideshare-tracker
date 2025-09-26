//
//  CloudSyncTests.swift
//  Rideshare TrackerTests
//
//  Created by Claude on 9/26/25.
//

import XCTest
import Foundation
import SwiftUI
@testable import Rideshare_Tracker

/// Tests for iCloud synchronization functionality and soft deletion
/// Migrated from original Rideshare_TrackerTests.swift (lines 812-1330)
final class CloudSyncTests: RideshareTrackerTestBase {

    // MARK: - AppPreferences Sync Settings Tests

    func testSyncPreferencesBasicFunctionality() async throws {
        // Simple test that doesn't mess with UserDefaults to avoid parallel execution issues
        await MainActor.run {
            let preferences = AppPreferences.shared

            // Save original state
            let originalSyncEnabled = preferences.incrementalSyncEnabled
            let originalSyncFrequency = preferences.syncFrequency
            let originalSyncDate = preferences.lastIncrementalSyncDate

            // Test setting and getting sync preferences
            preferences.incrementalSyncEnabled = true
            XCTAssertEqual(preferences.incrementalSyncEnabled, true, "Should be able to set sync enabled")

            preferences.syncFrequency = "Daily"
            XCTAssertEqual(preferences.syncFrequency, "Daily", "Should be able to set sync frequency")

            let testDate = Date()
            preferences.lastIncrementalSyncDate = testDate
            XCTAssertEqual(preferences.lastIncrementalSyncDate, testDate, "Should be able to set last sync date")

            // Test savePreferences doesn't crash
            preferences.savePreferences()

            // Restore original state
            preferences.incrementalSyncEnabled = originalSyncEnabled
            preferences.syncFrequency = originalSyncFrequency
            preferences.lastIncrementalSyncDate = originalSyncDate
        }
    }

    // MARK: - Data Model Sync Metadata Tests

    func testRideshareShiftHasSyncMetadata() throws {
        // Given/When
        let shift = RideshareShift(
            startDate: Date(),
            startMileage: 100.0,
            startTankReading: 8.0,
            hasFullTankAtStart: true,
            gasPrice: 2.00,
            standardMileageRate: 0.67
        )

        // Then
        XCTAssertTrue(shift.id != UUID(), "Shift should have a unique ID")
        XCTAssertTrue(shift.createdDate != Date(timeIntervalSince1970: 0), "Shift should have created date set")
        XCTAssertTrue(shift.modifiedDate != Date(timeIntervalSince1970: 0), "Shift should have modified date set")
        XCTAssertFalse(shift.deviceID.isEmpty, "Shift should have device ID set")
        XCTAssertEqual(shift.isDeleted, false, "Shift should not be marked as deleted by default")
    }

    func testExpenseItemHasSyncMetadata() throws {
        // Given/When
        let expense = ExpenseItem(
            date: Date(),
            category: .vehicle,
            description: "Test expense",
            amount: 25.0
        )

        // Then
        XCTAssertTrue(expense.id != UUID(), "Expense should have a unique ID")
        XCTAssertTrue(expense.createdDate != Date(timeIntervalSince1970: 0), "Expense should have created date set")
        XCTAssertTrue(expense.modifiedDate != Date(timeIntervalSince1970: 0), "Expense should have modified date set")
        XCTAssertFalse(expense.deviceID.isEmpty, "Expense should have device ID set")
        XCTAssertEqual(expense.isDeleted, false, "Expense should not be marked as deleted by default")
    }

    func testShiftSyncMetadataUpdate() async throws {
        // Given
        var shift = RideshareShift(
            startDate: Date(),
            startMileage: 100.0,
            startTankReading: 8.0,
            hasFullTankAtStart: true,
            gasPrice: 2.00,
            standardMileageRate: 0.67
        )
        let originalModifiedDate = shift.modifiedDate

        // Wait a bit to ensure time difference
        try await Task.sleep(nanoseconds: 1_000_000) // 1ms

        // When - simulate updating the shift
        shift.modifiedDate = Date()
        shift.endMileage = 200.0

        // Then
        XCTAssertTrue(shift.modifiedDate > originalModifiedDate, "Modified date should be updated when shift changes")
    }

    // MARK: - Data Migration Tests

    func testMigrateShiftWithoutSyncMetadata() throws {
        // Given - simulate an old shift without sync metadata
        var oldShift = RideshareShift(
            startDate: Date(),
            startMileage: 100.0,
            startTankReading: 8.0,
            hasFullTankAtStart: true,
            gasPrice: 2.00,
            standardMileageRate: 0.67
        )
        oldShift.endDate = Date().addingTimeInterval(3600)
        oldShift.endMileage = 150.0

        // Clear sync metadata to simulate old record
        oldShift.deviceID = "unknown"
        _ = oldShift.createdDate // Verify it exists

        // When - simulate migration logic
        if oldShift.deviceID.isEmpty || oldShift.deviceID == "unknown" {
            oldShift.createdDate = oldShift.startDate
            oldShift.modifiedDate = oldShift.endDate ?? oldShift.startDate
            oldShift.deviceID = "migrated-device-id"
            oldShift.isDeleted = false
        }

        // Then
        XCTAssertEqual(oldShift.createdDate, oldShift.startDate, "Created date should be set to start date during migration")
        XCTAssertEqual(oldShift.modifiedDate, oldShift.endDate, "Modified date should be set to end date during migration")
        XCTAssertEqual(oldShift.deviceID, "migrated-device-id", "Device ID should be updated during migration")
        XCTAssertEqual(oldShift.isDeleted, false, "isDeleted should be set to false during migration")
    }

    func testMigrateExpenseWithoutSyncMetadata() throws {
        // Given - simulate an old expense without sync metadata
        var oldExpense = ExpenseItem(
            date: Date(),
            category: .vehicle,
            description: "Old expense",
            amount: 50.0
        )

        // Clear sync metadata to simulate old record
        oldExpense.deviceID = ""

        // When - simulate migration logic
        if oldExpense.deviceID.isEmpty || oldExpense.deviceID == "unknown" {
            oldExpense.createdDate = oldExpense.date
            oldExpense.modifiedDate = oldExpense.date
            oldExpense.deviceID = "migrated-device-id"
            oldExpense.isDeleted = false
        }

        // Then
        XCTAssertEqual(oldExpense.createdDate, oldExpense.date, "Created date should be set to expense date during migration")
        XCTAssertEqual(oldExpense.modifiedDate, oldExpense.date, "Modified date should be set to expense date during migration")
        XCTAssertEqual(oldExpense.deviceID, "migrated-device-id", "Device ID should be updated during migration")
        XCTAssertEqual(oldExpense.isDeleted, false, "isDeleted should be set to false during migration")
    }

    // MARK: - Initial Sync Detection Tests

    func testDetectFirstTimeSyncEnable() async throws {
        // Given
        await MainActor.run {
            let preferences = AppPreferences.shared
            let originalSyncDate = preferences.lastIncrementalSyncDate

            // Reset to test state
            preferences.lastIncrementalSyncDate = nil

            // When/Then - First time enabling should be detectable
            let isFirstTimeEnabling = preferences.lastIncrementalSyncDate == nil
            XCTAssertEqual(isFirstTimeEnabling, true, "Should detect first time sync enabling")

            // When - after initial sync
            preferences.lastIncrementalSyncDate = Date()

            // Then
            let isStillFirstTime = preferences.lastIncrementalSyncDate == nil
            XCTAssertEqual(isStillFirstTime, false, "Should not detect first time after sync date is set")

            // Restore original state
            preferences.lastIncrementalSyncDate = originalSyncDate
        }
    }

    // MARK: - Backup Creation with Sync Support Tests

    func testCreateFullBackupWithSyncMetadata() async throws {
        // Given
        let shiftWithSyncData = RideshareShift(
            startDate: Date(),
            startMileage: 100.0,
            startTankReading: 8.0,
            hasFullTankAtStart: true,
            gasPrice: 2.00,
            standardMileageRate: 0.67
        )

        let expenseWithSyncData = ExpenseItem(
            date: Date(),
            category: .vehicle,
            description: "Test expense with sync data",
            amount: 25.0
        )

        // When
        let backupURL = await MainActor.run {
            let preferences = AppPreferences.shared
            return preferences.createFullBackup(shifts: [shiftWithSyncData], expenses: [expenseWithSyncData])
        }

        // Then
        XCTAssertNotNil(backupURL, "Full backup should be created successfully")

        if let url = backupURL {
            // Verify the backup contains the sync metadata
            let backupData = try Data(contentsOf: url)
            let backupJson = try JSONSerialization.jsonObject(with: backupData) as! [String: Any]

            XCTAssertNotNil(backupJson["shifts"], "Backup should contain shifts")
            XCTAssertNotNil(backupJson["expenses"], "Backup should contain expenses")

            let shifts = backupJson["shifts"] as! [[String: Any]]
            let expenses = backupJson["expenses"] as! [[String: Any]]

            XCTAssertEqual(shifts.count, 1, "Should have one shift in backup")
            XCTAssertEqual(expenses.count, 1, "Should have one expense in backup")

            // Verify sync metadata is preserved in backup
            let firstShift = shifts[0]
            XCTAssertNotNil(firstShift["createdDate"], "Shift backup should include createdDate")
            XCTAssertNotNil(firstShift["modifiedDate"], "Shift backup should include modifiedDate")
            XCTAssertNotNil(firstShift["deviceID"], "Shift backup should include deviceID")
            XCTAssertNotNil(firstShift["isDeleted"], "Shift backup should include isDeleted")

            let firstExpense = expenses[0]
            XCTAssertNotNil(firstExpense["createdDate"], "Expense backup should include createdDate")
            XCTAssertNotNil(firstExpense["modifiedDate"], "Expense backup should include modifiedDate")
            XCTAssertNotNil(firstExpense["deviceID"], "Expense backup should include deviceID")
            XCTAssertNotNil(firstExpense["isDeleted"], "Expense backup should include isDeleted")

            // Clean up test file
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Sync Frequency Validation Tests

    func testSyncFrequencyOptions() async throws {
        // Given
        await MainActor.run {
            let preferences = AppPreferences.shared
            let originalSyncFrequency = preferences.syncFrequency
            let validFrequencies = ["Immediate", "Hourly", "Daily"]

            // When/Then
            for frequency in validFrequencies {
                preferences.syncFrequency = frequency

                XCTAssertEqual(preferences.syncFrequency, frequency, "Should accept valid sync frequency: \(frequency)")
            }

            // Restore original state
            preferences.syncFrequency = originalSyncFrequency
        }
    }

    func testDefaultSyncFrequency() async throws {
        // Given/When
        await MainActor.run {
            let preferences = AppPreferences.shared
            let originalSyncFrequency = preferences.syncFrequency

            // Reset to default for testing
            preferences.syncFrequency = "Immediate"

            // Then
            XCTAssertEqual(preferences.syncFrequency, "Immediate", "Default sync frequency should be Immediate")

            // Restore original state
            preferences.syncFrequency = originalSyncFrequency
        }
    }

    // MARK: - Data Manager Sync Integration Tests

    func testExpenseManagerSaveIsPublic() async throws {
        // Given
        let manager = await ExpenseDataManager(forEnvironment: true)
        let testExpense = ExpenseItem(
            date: Date(),
            category: .vehicle,
            description: "Test save access",
            amount: 10.0
        )

        // When - This should compile without error (testing public access)
        await MainActor.run {
            manager.addExpense(testExpense)
            manager.saveExpenses() // This line tests that saveExpenses is public
        }

        // Then - Verify the expense was added and saved
        let expenses = await manager.expenses
        XCTAssertTrue(expenses.contains { $0.description == "Test save access" }, "Expense should be added to manager")
    }

    func testShiftDataManagerPreservesMetadata() async throws {
        // Given
        let manager = await ShiftDataManager(forEnvironment: true)
        var testShift = createBasicTestShift()
        testShift.deviceID = "test-device-123"
        testShift.modifiedDate = Date()

        // When
        await MainActor.run {
            manager.addShift(testShift)
            manager.saveShifts()
        }

        // Create new manager to test persistence
        let newManager = await ShiftDataManager(forEnvironment: true)

        // Then
        let shifts = await newManager.shifts
        XCTAssertTrue(shifts.count > 0, "Shifts should be loaded from persistence")

        let loadedShift = shifts.first { $0.id == testShift.id }
        XCTAssertNotNil(loadedShift, "Test shift should be found in loaded data")

        if let loaded = loadedShift {
            XCTAssertEqual(loaded.deviceID, "test-device-123", "Device ID should be preserved through save/load")
            XCTAssertEqual(loaded.isDeleted, false, "isDeleted should be preserved through save/load")
        }
    }

    func testExpenseDataManagerPreservesMetadata() async throws {
        // Given
        let manager = await ExpenseDataManager(forEnvironment: true)
        var testExpense = ExpenseItem(
            date: Date(),
            category: .equipment,
            description: "Test metadata preservation",
            amount: 75.0
        )
        testExpense.deviceID = "test-device-456"
        testExpense.modifiedDate = Date()

        // When
        await MainActor.run {
            manager.addExpense(testExpense)
            manager.saveExpenses()
        }

        // Create new manager to test persistence
        let newManager = await ExpenseDataManager(forEnvironment: true)

        // Then
        let expenses = await newManager.expenses
        XCTAssertTrue(expenses.count > 0, "Expenses should be loaded from persistence")

        let loadedExpense = expenses.first { $0.id == testExpense.id }
        XCTAssertNotNil(loadedExpense, "Test expense should be found in loaded data")

        if let loaded = loadedExpense {
            XCTAssertEqual(loaded.deviceID, "test-device-456", "Device ID should be preserved through save/load")
            XCTAssertEqual(loaded.isDeleted, false, "isDeleted should be preserved through save/load")
        }
    }

    // MARK: - Soft Deletion Tests

    func testActiveShiftsFiltersSoftDeletedRecords() async throws {
        let manager = await ShiftDataManager(forEnvironment: true)

        // Create test shifts - one active, one soft-deleted
        var activeShift = createBasicTestShift()
        activeShift.isDeleted = false

        var deletedShift = createBasicTestShift()
        deletedShift.isDeleted = true

        // Add both shifts to manager
        await MainActor.run {
            manager.shifts = [activeShift, deletedShift]
        }

        // Test activeShifts property filters out soft-deleted records
        let activeShifts = await manager.activeShifts
        XCTAssertEqual(activeShifts.count, 1, "activeShifts should only return non-deleted records")
        XCTAssertEqual(activeShifts.first?.id, activeShift.id, "activeShifts should return the active shift")
        XCTAssertFalse(activeShifts.contains { $0.isDeleted }, "activeShifts should not contain deleted records")
    }

    func testActiveExpensesFiltersSoftDeletedRecords() async throws {
        let manager = await ExpenseDataManager(forEnvironment: true)

        // Create test expenses - one active, one soft-deleted
        var activeExpense = ExpenseItem(date: Date(), category: .equipment, description: "Phone Mount", amount: 50.0)
        activeExpense.isDeleted = false

        var deletedExpense = ExpenseItem(date: Date(), category: .vehicle, description: "Repair", amount: 100.0)
        deletedExpense.isDeleted = true

        // Add both expenses to manager
        await MainActor.run {
            manager.expenses = [activeExpense, deletedExpense]
        }

        // Test activeExpenses property filters out soft-deleted records
        let activeExpenses = await manager.activeExpenses
        XCTAssertEqual(activeExpenses.count, 1, "activeExpenses should only return non-deleted records")
        XCTAssertEqual(activeExpenses.first?.id, activeExpense.id, "activeExpenses should return the active expense")
        XCTAssertFalse(activeExpenses.contains { $0.isDeleted }, "activeExpenses should not contain deleted records")
    }

    func testConditionalDeletionWithSyncEnabled() async throws {
        let manager = await ShiftDataManager(forEnvironment: true)

        // Clear any existing shifts first
        await MainActor.run {
            manager.shifts.removeAll()
        }

        // Enable cloud sync
        await MainActor.run {
            let preferences = AppPreferences.shared
            preferences.incrementalSyncEnabled = true
        }

        let testShift = createBasicTestShift()
        await MainActor.run {
            manager.addShift(testShift)
            // Delete shift with sync enabled - should be soft deleted
            manager.deleteShift(testShift)
        }

        // Verify shift is soft-deleted, not hard-deleted
        let shifts = await manager.shifts
        let activeShifts = await manager.activeShifts
        XCTAssertEqual(shifts.count, 1, "Shift should still exist in shifts array")
        XCTAssertEqual(shifts.first?.isDeleted, true, "Shift should be marked as deleted")
        XCTAssertEqual(activeShifts.count, 0, "activeShifts should not include soft-deleted shift")

        // Cleanup
        await MainActor.run {
            let preferences = AppPreferences.shared
            preferences.incrementalSyncEnabled = false
        }
    }

    func testConditionalDeletionWithSyncDisabled() async throws {
        let manager = await ShiftDataManager(forEnvironment: true)

        // Clear any existing shifts first
        await MainActor.run {
            manager.shifts.removeAll()
        }

        // Disable cloud sync
        await MainActor.run {
            let preferences = AppPreferences.shared
            preferences.incrementalSyncEnabled = false
        }

        let testShift = createBasicTestShift()
        await MainActor.run {
            manager.addShift(testShift)
            // Delete shift with sync disabled - should be hard deleted
            manager.deleteShift(testShift)
        }

        // Verify shift is completely removed
        let shifts = await manager.shifts
        let activeShifts = await manager.activeShifts
        XCTAssertEqual(shifts.count, 0, "Shift should be completely removed from shifts array")
        XCTAssertEqual(activeShifts.count, 0, "activeShifts should be empty")
    }

    func testAutomaticCleanupOfSoftDeletedRecords() async throws {
        let manager = await ShiftDataManager(forEnvironment: true)

        // Disable sync to trigger cleanup
        await MainActor.run {
            let preferences = AppPreferences.shared
            preferences.incrementalSyncEnabled = false
        }

        // Create shifts with mixed deletion status
        var activeShift = createBasicTestShift()
        activeShift.isDeleted = false

        var deletedShift1 = createBasicTestShift()
        deletedShift1.isDeleted = true

        var deletedShift2 = createBasicTestShift()
        deletedShift2.isDeleted = true

        // Manually set shifts to simulate loaded data with soft-deleted records
        await MainActor.run {
            manager.shifts = [activeShift, deletedShift1, deletedShift2]
            // Trigger cleanup (simulates what happens during loadShifts)
            manager.cleanupDeletedShifts()
        }

        // Verify only active shifts remain
        let shifts = await manager.shifts
        XCTAssertEqual(shifts.count, 1, "Only active shifts should remain after cleanup")
        XCTAssertEqual(shifts.first?.id, activeShift.id, "The remaining shift should be the active one")
        XCTAssertFalse(shifts.contains { $0.isDeleted }, "No soft-deleted shifts should remain")
    }

    func testExpenseFilteringInMonthlyQueries() async throws {
        let manager = await ExpenseDataManager(forEnvironment: true)

        let currentDate = Date()

        // Create expenses for current month - one active, one deleted
        var activeExpense = ExpenseItem(date: currentDate, category: .supplies, description: "Cleaning Supplies", amount: 50.0)
        activeExpense.isDeleted = false

        var deletedExpense = ExpenseItem(date: currentDate, category: .vehicle, description: "Oil Change", amount: 100.0)
        deletedExpense.isDeleted = true

        await MainActor.run {
            manager.expenses = [activeExpense, deletedExpense]
        }

        // Test monthly queries filter out deleted expenses
        let monthExpenses = await manager.expensesForMonth(currentDate)
        XCTAssertEqual(monthExpenses.count, 1, "Monthly expenses should exclude deleted records")
        XCTAssertEqual(monthExpenses.first?.id, activeExpense.id, "Should return only the active expense")

        // Test monthly total excludes deleted expenses
        let monthTotal = await manager.totalForMonth(currentDate)
        assertCurrency(monthTotal, equals: 50.0, "Monthly total should only include active expenses")
    }
}